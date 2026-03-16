import 'package:flutter/material.dart';
import 'dart:core';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'screen_select_dialog.dart';
import 'signaling.dart';
import 'mqtt_server_client.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';
  final String host = 'stun.l.google.com';
  final int port = 19302;
  MqttComms mqttComms;
  CallSample(this.mqttComms);

  @override
  CallSampleState createState() => CallSampleState(this.mqttComms);
}

class CallSampleState extends State<CallSample> {
  Signaling? _signaling;
  List<dynamic> _peers = [];
  String? _selfId;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  Session? _session;
  bool _waitAccept = false;
  MqttComms mqttComms;

  // ignore: unused_element
  CallSampleState(this.mqttComms);

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect(context);
  }

  initRenderers() async {
    await _localRenderer.initialize();
    print('P2PCall::local renderer initialized');
    await _remoteRenderer.initialize();
    print('P2PCall::remote renderer initialized');
  }

  @override
  deactivate() {
    super.deactivate();
    _signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect(BuildContext context) async {
    _signaling ??= Signaling(widget.host, widget.port, context, this.mqttComms)..connect();

    _signaling?.onCallStateChange = (Session session, CallState state) async {
      switch (state) {
        case CallState.callStateNew:
          setState(() {
            _session = session;
          });
        case CallState.callStateRinging:
          _accept();
          setState(() {
            _inCalling = true;
          });
        case CallState.callStateBye:
          if (_waitAccept) {
            print('peer reject');
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });
        case CallState.callStateInvite:
          _waitAccept = true;
          _showInvateDialog();
        case CallState.callStateConnected:
          if (_waitAccept) {
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _inCalling = true;
          });
      }
    };

    _signaling?.onPeersUpdate = ((event) {
      setState(() {
        _selfId = event['self'];
        _peers = event['peers'];
        _invitePeer(context, _peers[0]);
      });
    });

    _signaling?.onLocalStream = ((stream) {
      _localRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onAddRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onRemoveRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = null;
    });
  }

  Future<bool?> _showInvateDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("title"),
          content: Text("waiting"),
          actions: <Widget>[
            TextButton(
              child: Text("cancel"),
              onPressed: () {
                Navigator.of(context).pop(false);
                _hangUp();
              },
            ),
          ],
        );
      },
    );
  }

  _invitePeer(BuildContext context, String peerId) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling?.invite(peerId, 'video');
    }
  }

  _accept() {
    if (_session != null) {
      _signaling?.accept(_session!.sid, 'video');
    }
  }

  _hangUp() {
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
  }

  Future<void> selectScreenSourceDialog(BuildContext context) async {
    MediaStream? screenStream;
    if (WebRTC.platformIsDesktop) {
      final source = await showDialog<DesktopCapturerSource>(
        context: context,
        builder: (context) => ScreenSelectDialog(),
      );
      if (source != null) {
        try {
          var stream =
              await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
            'video': {
              'deviceId': {'exact': source.id},
              'mandatory': {'frameRate': 30.0}
            }
          });
          stream.getVideoTracks()[0].onEnded = () {
            print(
                'By adding a listener on onEnded you can: 1) catch stop video sharing on Web');
          };
          screenStream = stream;
        } catch (e) {
          print(e);
        }
      }
    } else if (WebRTC.platformIsWeb) {
      screenStream =
          await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'audio': false,
        'video': true,
      });
    }
    if (screenStream != null) _signaling?.switchToScreenSharing(screenStream);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call Sample${_selfId != null ? ' [Your ID ($_selfId)] ' : ''}'),
      ),
      body: OrientationBuilder(builder: (context, orientation) {
        return Stack(children: <Widget>[
            Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(color: Colors.black54),
                  child: RTCVideoView(_remoteRenderer),
                )),
            Positioned(
              left: 20.0,
              top: 20.0,
              child: Container(
                width: orientation == Orientation.portrait ? 90.0 : 120.0,
                height:
                    orientation == Orientation.portrait ? 120.0 : 90.0,
                decoration: BoxDecoration(color: Colors.black54),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),
          ]);
      })
    );
  }
}