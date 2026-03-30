import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:core';
import 'dart:async';

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
  Session? _session;
  bool _waitAccept = false;
  bool _dataRecieved = false;
  Timer? _disconnectChecker;
  RTCDataChannel? _dataChannel;
  final GlobalKey<ImageChangerState> imageChangerKey = GlobalKey<ImageChangerState>();
  ImageChanger get video => ImageChanger(key: imageChangerKey);

  CallSampleState(this.signaling);

  @override
  initState() {
    super.initState();
    _connect(context);
    _disconnectChecker = Timer.periodic(const Duration(seconds: 20), checkConnection);
  }

  @override
  deactivate() {
    super.deactivate();
    signaling?.close();
  }

  // If data is not recieved for 20 seconds, assume connection is lost and try to reconnect
  void checkConnection(Timer _)
  {
    if (_dataRecieved == false)
    {
      // Timeout
      print('P2PCall::Connection Timeout');
      signaling?.invite("1");
    }
    _dataRecieved = false;
  }

  void _connect(BuildContext context) async {
    signaling?.onCallStateChange = (Session session, CallState state) async {
      print('P2PCall::onCallStateChange => sessionId: ${session.sid}, state: $state');
      switch (state) {
        case CallState.callStateNew:
          setState(() {
            _session = session;
          });
        case CallState.callStateRinging:
          _accept();
          setState(() {});
        case CallState.callStateBye:
          if (_waitAccept) {
            print('peer reject');
            _waitAccept = false;
          }
          setState(() {
            _session = null;
          });
        case CallState.callStateInvite:
          _waitAccept = true;
        case CallState.callStateConnected:
          if (_waitAccept) {
            _waitAccept = false;
          }
          setState(() {});
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
          //print('P2PCall::Got binary Data');
            imageChangerKey.currentState?.updateImage(data.binary);
            _dataRecieved = true;
        } else {
          print('P2PCall::Got String Data');

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
    return OrientationBuilder(builder: (context, orientation) {
        return Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(color: Colors.black54),
                  child: video,
                );
      });
  }
}