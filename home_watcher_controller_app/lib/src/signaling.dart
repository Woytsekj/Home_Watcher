import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'random_string.dart';
import 'mqtt_server_client.dart';
//import 'turn.dart';

enum SignalingState {
  connectionOpen,
  connectionClosed,
  connectionError,
}

enum CallState {
  callStateNew,
  callStateRinging,
  callStateInvite,
  callStateConnected,
  callStateBye,
}

enum VideoSource {
  camera,
  screen,
}

class Session {
  Session({required this.sid, required this.pid});
  String pid;
  String sid;
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class Signaling {
  Signaling(this.mqttComms)
  {
    mqttComms.onWebRTCMessageReceived = onMessage;
  }

  JsonEncoder _encoder = JsonEncoder();
  JsonDecoder _decoder = JsonDecoder();
  String _selfId = randomNumeric(6);
  MqttComms mqttComms;
  //var _turnCredential;
  Map<String, Session> _sessions = {};
  List<MediaStream> _remoteStreams = <MediaStream>[];
  List<RTCRtpSender> _senders = <RTCRtpSender>[];

  Function(Session session, CallState state)? onCallStateChange;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)? onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;

  String get sdpSemantics => 'unified-plan';

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:ec2-3-149-184-208.us-east-2.compute.amazonaws.com:3478'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  close() async {
    await _cleanSessions();
  }

  void invite(String peerId) async {
    print("Signaling::invite => peerId: $peerId");
    var sessionId = '$_selfId-$peerId';
    Session session = await _createSession(null,
        peerId: peerId,
        sessionId: sessionId,
        screenSharing: false);
    _sessions[sessionId] = session;
    _createDataChannel(session);
    _createOffer(session);
    onCallStateChange?.call(session, CallState.callStateNew);
    onCallStateChange?.call(session, CallState.callStateInvite);
  }

  void accept(String sessionId, String media) {
    var session = _sessions[sessionId];
    if (session == null) {
      return;
    }
    _createAnswer(session, media);
  }

  void onMessage(String message) async {
    Map<String, dynamic> mapData = _decoder.convert(message);

    switch (mapData['type']) {
      case 'peers':
        {
          List<dynamic> peers = mapData['peers'];
          if (onPeersUpdate != null) {
            Map<String, dynamic> event = <String, dynamic>{};
            event['self'] = _selfId;
            event['peers'] = peers;
            onPeersUpdate?.call(event);
          }
        }
      case 'answer':
        {
          var session = _sessions['1'];
          session?.pc?.setRemoteDescription(RTCSessionDescription(mapData['sdp'], 'answer'));
          onCallStateChange?.call(session!, CallState.callStateConnected);
        }
      case 'keepalive':
        {
          print('keepalive response!');
        }
      default:
        break;
    }
  }

  Future<Session> _createSession(
    Session? session, {
    required String peerId,
    required String sessionId,
    required bool screenSharing,
  }) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    pc.onIceCandidate = (candidate) async {
      // This delay is needed to allow enough time to try an ICE candidate
      // before skipping to the next one. 1 second is just an heuristic value
      // and should be thoroughly tested in your own environment.
      await Future.delayed(
          const Duration(seconds: 1),
          () => _send('candidate', 'candidate', candidate.candidate));
    };

    pc.onIceConnectionState = (state) {};

    pc.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    newSession.pc = pc;
    return newSession;
  }

  Future<void> _createOffer(Session session) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createOffer(_dcConstraints);
      await session.pc!.setLocalDescription(_fixSdp(s));
      /*
      _send('offer', {
        'description': {'sdp': s.sdp, 'type': s.type},
        'media': media,
      });
      */

      RTCSessionDescription a =
          await session.pc!.createAnswer(_dcConstraints);

      _send('offer', 'sdp', s.sdp);
    } catch (e) {
      print(e.toString());
    }
  }

  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }

  Future<void> _createAnswer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc!.createAnswer(media == 'data' ? _dcConstraints : {});
      await session.pc!.setLocalDescription(_fixSdp(s));
      _send('answer', 'sdp', s.sdp);
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, dataType, data) {
    var request = {};
    request["type"] = event;
    request[dataType] = data;
    mqttComms.publishMessage(mqttComms.controllerToRobotTopic, _encoder.convert(request));
  }

  Future<void> _cleanSessions() async {
    _sessions.forEach((key, sess) async {
      await sess.pc?.close();
    });
    _sessions.clear();
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }
  
  Future<void> _createDataChannel(Session session, {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()..maxRetransmits = 30;
    RTCDataChannel channel = await session.pc!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }
}