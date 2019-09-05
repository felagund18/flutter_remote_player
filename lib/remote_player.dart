import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';


enum RemotePlayerState {
  stopped,
  paused,
  playing,
  resuming,
  error
}

class RemotePlayer {
  final MethodChannel _channel = const MethodChannel('com.dralien/remote_player');
  final EventChannel _event = const EventChannel('com.dralien/remote_player/event');
  final List<Function> _durationEvents = [];
  final List<Function> _stateEvents = [];

  static final RemotePlayer instance = RemotePlayer();

  RemotePlayer() {
    _init();
  }

  void _init() {
    _event.receiveBroadcastStream().listen((obj) {
      if (obj['event'] == 'onDuration') {
        double _t = obj['duration'] * 1000;
        Duration _duration = Duration();
        _duration += Duration(milliseconds: _t.floor());

        _durationEvents.forEach((x) {
          x(_duration);
        });
      } else if (obj['event'] == 'onState') {
        _stateEvents.forEach((x) {
          for (var i = 0; i < RemotePlayerState.values.length; i++) {
            if (RemotePlayerState.values[i].index == obj['state']) {
              x(RemotePlayerState.values[i]);
              break;
            }
          }
        });
      }
    }, onError: (error) {
      print('error');
      print(error);
    });
  }

  onDurationChanged(Function function) {
    _durationEvents.add(function);
  }

  removeFromDurationChanged(Function function) {
    _durationEvents.remove(function);
  }

  onStateChanged(Function function) {
    _stateEvents.add(function);
  }

  removeFromStateChanged(Function function) {
    _stateEvents.remove(function);
  }

  Future<Map> setup() async {
    if (Platform.isAndroid) {
      var a = await _channel.invokeMethod('setup');
      return {
        'state': RemotePlayerState.stopped,
        'duration': Duration(),
      };
    } else {
      Map data = await _channel.invokeMethod('setup');

      double _duration = (data['duration'] * 1000);
      double _state = data['state'];

      print(data);

      data['state'] = RemotePlayerState.values[_state.toInt()];
      data['duration'] = Duration(milliseconds: _duration.toInt());
      return data;
    }
  }

  Future<String> play({title: String, artist: String, url: String, album: String}) async {
    final String val = await _channel.invokeMethod('play', {
      'url': url,
      'title': title,
      'artist': artist,
      'album': album,
    });
    return val;
  }

  Future<String> resume() async {
    final String val = await _channel.invokeMethod('resume');
    return val;
  }

  Future<String> stop() async {
    final String val = await _channel.invokeMethod('stop');
    return val;
  }

  Future<String> toggle() async {
    final String val = await _channel.invokeMethod('toggle');
    return val;
  }

  Future<String> pause() async {
    final String val = await _channel.invokeMethod('pause');
    return val;
  }
}