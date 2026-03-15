/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/05/2017
 * Copyright :  S.Hamblett
 */

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
//import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;

/// An annotated simple subscribe/publish usage example for mqtt_server_client. Please read in with reference
/// to the MQTT specification. The example is runnable, also refer to test/mqtt_client_broker_test...dart
/// files for separate subscribe/publish tests.

/// First create a client, the client is constructed with a broker name, client identifier
/// and port if needed. The client identifier (short ClientId) is an identifier of each MQTT
/// client connecting to a MQTT broker. As the word identifier already suggests, it should be unique per broker.
/// The broker uses it for identifying the client and the current state of the client. If you don’t need a state
/// to be hold by the broker, in MQTT 3.1.1 you can set an empty ClientId, which results in a connection without any state.
/// A condition is that clean session connect flag is true, otherwise the connection will be rejected.
/// The client identifier can be a maximum length of 23 characters. If a port is not specified the standard port
/// of 1883 is used.
/// If you want to use websockets rather than TCP see below.

class MqttComms {
  final client = MqttServerClient('ec2-3-149-184-208.us-east-2.compute.amazonaws.com', 'android');
  final topic = 'robotCommands';

  var pongCount = 0; // Pong counter
  var pingCount = 0; // Ping counter

  Future<int> setupClient() async {
    /// Set logging on if needed, defaults to off
    client.logging(on: false);

    /// Set the correct MQTT protocol for mosquito
    client.setProtocolV311();

    /// If you intend to use a keep alive you must set it here otherwise keep alive will be disabled.
    client.keepAlivePeriod = 20;

    /// The connection timeout period can be set, the default is 5 seconds.
    /// if [client.socketTimeout] is set then this will take precedence and this setting will be
    /// disabled.
    client.connectTimeoutPeriod = 2000; // milliseconds

    /// The socket timeout period can be set, the minimum value is 1000ms.
    /// If set then this setting takes precedence and [client.connectionTimeoutPeriod] is disabled.
    /// client.socketTimeout = 2000; // milliseconds

    /// Add the unsolicited disconnection callback
    client.onDisconnected = onDisconnected;

    /// Add the successful connection callback
    client.onConnected = onConnected;

    /// Add a subscribed callback, there is also an unsubscribed callback if you need it.
    /// You can add these before connection or change them dynamically after connection if
    /// you wish. There is also an onSubscribeFail callback for failed subscriptions, these
    /// can fail either because you have tried to subscribe to an invalid topic or the broker
    /// rejects the subscribe request.
    client.onSubscribed = onSubscribed;

    /// Set a ping received callback if needed, called whenever a ping response(pong) is received
    /// from the broker. Can be used for health monitoring.
    client.pongCallback = pong;

    /// Set a ping sent callback if needed, called whenever a ping request(ping) is sent
    /// by the client. Can be used for latency calculations.
    client.pingCallback = ping;

    // Set the port
    client.port =
      8883; // Secure port number for mosquitto, no client certificate required

    // Security context
    // Create the security context
    final context = SecurityContext.defaultContext;
    // Load and parse Cert
    final ByteData homeWatcherByteData = await rootBundle.load('certs/HomeWatcher.crt');
    final homeWatcherCrt = homeWatcherByteData.buffer.asUint8List();
    // Set Cert in context
    context.setTrustedCertificatesBytes(homeWatcherCrt);

    /// Set secure working
    client.secure = true;
    client.securityContext = context;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password and clean session,
    /// an example of a specific one below.
    final connMess = MqttConnectMessage()
        .authenticateAs('android', 'ENEDBAD')
        .withWillTopic('willtopic') // If you set this you must set a will message
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    print('MQTT::Mosquitto client connecting....');
    client.connectionMessage = connMess;

    // Connect to the server
    int connectionStatus = await connectToServer();

    if (connectionStatus == -1) {
      return -1;
    }

    /// Subscribe to topic ot posit messages to
    print('MQTT::Subscribing to the robotCommands topic');

    client.subscribe(topic, MqttQos.atMostOnce);
    // Setup and connection successful
    return 0;
  }
/*
  Future<int> testing() async {
    /// The client has a change notifier object(see the Observable class) which we then listen to to get
    /// notifications of published updates to each subscribed topic.
    /// In general you should listen here as soon as possible after connecting, you will not receive any
    /// publish messages until you do this.
    /// Also you must re-listen after disconnecting.
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      /// The above may seem a little convoluted for users only interested in the
      /// payload, some users however may be interested in the received publish message,
      /// lets not constrain ourselves yet until the package has been in the wild
      /// for a while.
      /// The payload is a byte buffer, this will be specific to the topic
      print(
        'EXAMPLE::Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->',
      );
      print('');
    });

    /// If needed you can listen for published messages that have completed the publishing
    /// handshake which is Qos dependant. Any message received on this stream has completed its
    /// publishing handshake with the broker.
    client.published!.listen((MqttPublishMessage message) {
      print(
        'EXAMPLE::Published notification:: topic is ${message.variableHeader!.topicName}, with Qos ${message.header!.qos}',
      );
    });

    /// Lets publish to our topic
    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    const pubTopic = 'Dart/Mqtt_client/testtopic';
    

    /// Subscribe to it
    print('EXAMPLE::Subscribing to the Dart/Mqtt_client/testtopic topic');
    client.subscribe(pubTopic, MqttQos.exactlyOnce);

    /// Publish it
    print('EXAMPLE::Publishing our topic');
    client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload!);

    /// Ok, we will now sleep a while, in this gap you will see ping request/response
    /// messages being exchanged by the keep alive mechanism.
    print('EXAMPLE::Sleeping....');
    await MqttUtilities.asyncSleep(60);

    /// Print the ping/pong cycle latency data before disconnecting.
    print('EXAMPLE::Keep alive latencies');
    print(
      'The latency of the last ping/pong cycle is ${client.lastCycleLatency} milliseconds',
    );
    print(
      'The average latency of all the ping/pong cycles is ${client.averageCycleLatency} milliseconds',
    );

    /// Finally, unsubscribe and exit gracefully
    print('EXAMPLE::Unsubscribing');
    client.unsubscribe(topic);

    /// Wait for the unsubscribe message from the broker if you wish.
    await MqttUtilities.asyncSleep(2);
    print('EXAMPLE::Disconnecting');
    client.disconnect();
    print('EXAMPLE::Exiting normally');
    return 0;
  }
*/
  /// The subscribed callback
  void onSubscribed(String topic) {
    print('MQTT::Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('MQTT::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus!.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited) {
      print('MQTT::OnDisconnected callback is solicited, this is correct');
    } else {
      print(
        'MQTT::OnDisconnected callback is unsolicited or none',
      );
    }
    if (pongCount == 3) {
      print('MQTT::Pong count is correct');
    } else {
      print('MQTT::Pong count is incorrect, expected 3. actual $pongCount');
    }
    if (pingCount == 3) {
      print('MQTT::Ping count is correct');
    } else {
      print('MQTT::Ping count is incorrect, expected 3. actual $pingCount');
    }
  }

  /// The successful connect callback
  void onConnected() {
    print(
      'MQTT::OnConnected client callback - Client connection was successful',
    );
  }

  /// Pong callback
  void pong() {
    print('MQTT::Ping response client callback invoked');
    pongCount++;
    print(
      'MQTT::Latency of this ping/pong cycle is ${client.lastCycleLatency} milliseconds',
    );
  }

  /// Ping callback
  void ping() {
    print('MQTT::Ping sent client callback invoked');
    pingCount++;
  }

  // Publish a robot command to the topic
  void publishCommand(String commandName)
  {
    final builder = MqttClientPayloadBuilder();
    String message  = commandName;
    print('MQTT::Send Command: $commandName');
    builder.addString(message);

    try
    {
      client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
    }
    on Exception catch (e)
    {
      print("MQTT::Exception in communication $e");
    }
  }

  
  Future<int> connectToServer() async {
    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      print('MQTT::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      print('MQTT::socket exception - $e');
      client.disconnect();
    }

    /// Check we are connected
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT::Mosquitto client connected');
    } else {
      /// Use status here rather than state if you also want the broker return code.
      print(
        'MQTT::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      client.disconnect();
      return -1;
    }

    return 0;
  }

  // Disconnect From the server
  void disconnectFromServer() 
  {
    client.disconnect();
  }
}

