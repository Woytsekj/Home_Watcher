import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:core';

import 'signaling.dart';
import 'jpeg_video.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';
  final String host = 'stun.l.google.com';
  final int port = 19302;
  late final Signaling? signaling;
  CallSample(this.signaling);

  @override
  CallSampleState createState() => CallSampleState(signaling);
}

class CallSampleState extends State<CallSample> {
  Signaling? signaling;
  List<dynamic> _peers = [];
  String? _selfId;
  bool _inCalling = false;
  Session? _session;
  bool _waitAccept = false;
  RTCDataChannel? _dataChannel;
  final GlobalKey<ImageChangerState> imageChangerKey = GlobalKey<ImageChangerState>();
  ImageChanger get video => ImageChanger(key: imageChangerKey);

  // ignore: unused_element
  CallSampleState(this.signaling);

  @override
  initState() {
    super.initState();
    _connect(context);
  }

  @override
  deactivate() {
    super.deactivate();
    signaling?.close();
  }

  void _connect(BuildContext context) async {
    signaling?.onCallStateChange = (Session session, CallState state) async {
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
            _inCalling = false;
            _session = null;
          });
        case CallState.callStateInvite:
          _waitAccept = true;
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

    signaling?.onPeersUpdate = ((event) {
      setState(() {
        _selfId = event['self'];
        _peers = event['peers'];
        invitePeer(context, _peers[0]);
      });
    });

    signaling?.onDataChannelMessage = (_, dc, RTCDataChannelMessage data) {
      setState(() {
        if (data.isBinary) {
          print('P2PCall::Got binary Data [${data.binary}]');
            imageChangerKey.currentState?.updateImage(data.binary);
        } else {
          print('P2PCall::Got String Data [${data.text}]');

        }});
    };

    signaling?.onDataChannel = (_, channel) {
      _dataChannel = channel;
    };

    // Start Requesting Dialog
    print('P2PCall::Invite Robot to Data Stream');
    Future.delayed(Duration(seconds: 5), () {
      signaling?.invite("1");
    });
  }

  invitePeer(BuildContext context, String peerId) async {
    if (signaling != null && peerId != _selfId) {
      signaling?.invite(peerId);
    }
  }

  _accept() {
    if (_session != null) {
      signaling?.accept(_session!.sid, 'video');
    }
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
                  child: video,
                ))
          ]);
      })
    );
  }
}