import 'package:flutter/material.dart';
import 'package:remote_player/remote_player.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  Duration _duration = Duration();
  RemotePlayerState _state;

  @override
  void initState() {
    super.initState();

    RemotePlayer.instance.setup().then((e) {
      RemotePlayer.instance.onDurationChanged((Duration x) {
        setState(() {
          _duration = x;
        });
      });

      RemotePlayer.instance.onStateChanged((state) {
        setState(() {
          _state = state;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              RaisedButton(child: Text('play'),onPressed: () async {
                await RemotePlayer.instance.play(
                  url: 'http://35.221.107.46/audios/itgel/stream.m3u8',
                  artist: 'Artist',
                  title: 'Title',
                  album: 'Album',
                );
              },),
              RaisedButton(child: Text('pause'),onPressed: () async {
                await RemotePlayer.instance.pause();
              },),
              RaisedButton(child: Text('resume'),onPressed: () async {
                await RemotePlayer.instance.resume();
              },),
              RaisedButton(child: Text('stop'),onPressed: () async {
                await RemotePlayer.instance.stop();
              },),
              RaisedButton(child: Text('toggle'),onPressed: () async {
                await RemotePlayer.instance.toggle();
              },),
              Text(_duration.toString()),
              Text(_state.toString()),
            ],
          ),
        ),
      ),
    );
  }
}