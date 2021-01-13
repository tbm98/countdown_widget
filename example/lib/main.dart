import 'package:countdown_widget/countdown_widget.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CountDownController _countDownController;

  void pause() {
    _countDownController.pause();
  }

  void resume() {
    _countDownController.resume();
  }

  void restart() {
    _countDownController.restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: CountDownWidget(
          duration: Duration(seconds: 20),
          builder: (context, duration) {
            return Text(duration.inSeconds.toString());
          },
          onControllerReady: (controller) {
            _countDownController = controller;
          },
          onDurationRemainChanged: (duration) {
            print('duration:${duration.toString()}');
          },
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: pause,
            child: Text('pause'),
          ),
          FloatingActionButton(
            onPressed: resume,
            child: Text('resume'),
          ),
          FloatingActionButton(
            onPressed: restart,
            child: Text('restart'),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
