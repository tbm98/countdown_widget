library countdown_widget;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mutex/mutex.dart';

/// Widget builder when duration changed
typedef BuildWidgetByDuration = Widget Function(
    BuildContext context, Duration duration);

/// callback this return [CountDownController] when it ready to use
typedef OnControllerReady = void Function(CountDownController controller);

/// Controller of CountDownWidget, if you want to pause,resume,restart timer,
/// you need use controller, get a controller by
/// [CountDownWidget.onControllerReady]
class CountDownController {
  // ignore: prefer_function_declarations_over_variables
  VoidCallback _pause = () {
    throw UnimplementedError('Pause callback is not implement yet !');
  };

  // ignore: prefer_function_declarations_over_variables
  VoidCallback _resume = () {
    throw UnimplementedError('Resume callback is not implement yet !');
  };

  // ignore: prefer_function_declarations_over_variables
  VoidCallback _restart = () {
    throw UnimplementedError('Restart callback is not implement yet !');
  };

  /// pause timer, if timer is paused => do nothing
  VoidCallback get pause => _pause;

  /// resume timer, if timer is runner => do nothing
  VoidCallback get resume => _resume;

  /// restart timer doesn't care about its state
  VoidCallback get restart => _restart;

  void _addPauseCallback(VoidCallback onPause) {
    _pause = onPause;
  }

  void _addResumeCallback(VoidCallback onResume) {
    _resume = onResume;
  }

  void _addRestartCallback(VoidCallback onRestart) {
    _restart = onRestart;
  }
}

/// [builder] is function callback return Widget by durationRemain, it will be
/// called when durationRemain Changed
///
/// [onControllerReady] is function callback, it will be called when
/// [CountDownTimerController] is ready to use
///
/// [onExpired] it will be called when [duration] is less than or equal
/// to [durationExpired]
///
/// [onFinish] it will be called when countdown finish
///
/// [onDurationRemainChanged] it will be called when [duration] changed
///
/// [durationExpired] is duration to check when countdown reach to timeExpire
/// ex: if you want to set time expire when countdown to 00:30, set
/// [durationExpired] = [Duration(seconds: 30)]
///
/// [duration] is total time you want to countdown, ex: you want countdown
/// from 01:20 -> 00:00 set [duration] = [Duration(seconds: 120)]
///
/// [runWhenSleep] default is true
///
/// -- if true: [onDurationRemainChanged] will be called even when the phone
/// turns off the screen
///
/// -- if false: [onDurationRemainChanged] will not be called when the phone
/// turns off the screen
///
/// Note, whether you set [runWhenSleep] to true or false, when the app is
/// reopened, the timer will still count the amount of time you turn off
/// the screen, but it won't count if you call the controller.pause function.
class CountDownWidget extends StatefulWidget {
  const CountDownWidget({
    Key key,
    @required Duration duration,
    @required this.builder,
    this.onControllerReady,
    this.onExpired,
    this.onFinish,
    this.onDurationRemainChanged,
    this.durationExpired,
    this.runWhenSleep = true,
    this.autoStart = true,
  })  : assert(duration != null && builder != null),
        _duration = duration,
        super(key: key);

  /// Widget builder when duration remain changed
  final BuildWidgetByDuration builder;

  /// callback return [CountDownController] when it ready to use
  final OnControllerReady onControllerReady;

  /// callback when timer reach to [durationExpired]
  final VoidCallback onExpired;

  /// callback when timer is done
  final VoidCallback onFinish;

  /// callback when duration remain changed
  final ValueChanged<Duration> onDurationRemainChanged;

  /// if duration remain is less than or equal [durationExpired], [onExpired]
  /// will be called, default [durationExpired] = const Duration()
  final Duration durationExpired;

  final Duration _duration;

  /// [runWhenSleep] default is true
  ///
  /// -- if true: [onDurationRemainChanged] will be called even when the phone
  /// turns off the screen
  ///
  /// -- if false: [onDurationRemainChanged] will not be called when the phone
  /// turns off the screen
  ///
  /// Note, whether you set [runWhenSleep] to true or false, when the app is
  /// reopened, the timer will still count the amount of time you turn off
  /// the screen, but it won't count if you call the controller.pause function.
  final bool runWhenSleep;

  /// [autoStart] is flag to config timer will auto start or not, default is
  /// true
  final bool autoStart;

  Duration get duration {
    // add 999 millisecond to delay first count
    return Duration(milliseconds: _duration.inMilliseconds + 999);
  }

  @override
  State createState() => _CountDownWidgetState();
}

class _CountDownWidgetState extends State<CountDownWidget>
    with WidgetsBindingObserver {
  Timer _timer;
  DateTime _startTime;
  Duration _durationRemainWhenPause;
  DateTime _expiredTime;
  Duration _durationRemain;
  bool _isPause = false;
  CountDownController _countDownTimerController = CountDownController();
  final Mutex _mutex = Mutex();

  @override
  void initState() {
    super.initState();
    _setupController();
    _computeTime();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _restartTimer();
      });
    }
  }

  void _setupController() {
    _initPauseCallback();
    _initResumeCallback();
    _initRestartCallback();
    widget.onControllerReady?.call(_countDownTimerController);
  }

  void _initRestartCallback() {
    _countDownTimerController._addRestartCallback(() {
      if (!mounted || _timer == null) {
        return;
      }
      _isPause = false;
      _restartTimer();
    });
  }

  void _initResumeCallback() {
    _countDownTimerController._addResumeCallback(() {
      if (!mounted || _timer == null) {
        return;
      }
      if (!_timer.isActive) {
        _isPause = false;
        _computeTimeWhenResume();
        _startTimer();
      }
    });
  }

  void _initPauseCallback() {
    _countDownTimerController._addPauseCallback(() {
      if (!mounted || _timer == null) {
        return;
      }
      if (_timer.isActive) {
        _isPause = true;
        _timer.cancel();
        _durationRemainWhenPause = _durationRemain;
      }
    });
  }

  void _computeTime() {
    _startTime = DateTime.now();
    _expiredTime = _startTime.add(widget.duration);
    _durationRemain = widget.duration;
  }

  void _computeTimeWhenResume() {
    _startTime = DateTime.now();
    _expiredTime = _startTime.add(_durationRemainWhenPause);
    _durationRemain = _durationRemainWhenPause;
  }

  void _startTimer() async {
    await _mutex.protect(() async {
      _timer = Timer.periodic(
        // check for update durationRamain each 100 millisecond
        const Duration(milliseconds: 100),
        (_) {
          _handleDurationChanged();
        },
      );
    });
  }

  void _handleDurationChanged() {
    final newDurationRemain = _expiredTime.difference(DateTime.now());
    // if new duration have same second value to old duration => do nothing
    if (_durationRemain.inSeconds == newDurationRemain.inSeconds) {
      return;
    }
    _durationRemain = newDurationRemain;

    if (_durationRemain.inSeconds <=
        (widget.durationExpired ?? const Duration()).inSeconds) {
      widget.onExpired?.call();
    }

    if (_durationRemain.inSeconds <= 0) {
      _durationRemain = const Duration();
      _timer.cancel();
      widget.onFinish?.call();
    }

    widget.onDurationRemainChanged?.call(_durationRemain);

    setState(() {});
  }

  void _restartTimer() {
    if (_timer?.isActive ?? false) {
      _timer.cancel();
    }
    _computeTime();
    setState(() {});
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _durationRemain);
  }

  @override
  void didUpdateWidget(CountDownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      // restart timer if parent widget change state and durationRemain is
      // updated
      _restartTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.runWhenSleep) {
      return;
    }
    if (state == AppLifecycleState.paused) {
      if (_timer.isActive) {
        _timer.cancel();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_timer.isActive && !_isPause) {
        // only startTimer when current state is running,
        // if current state is pause, do nothing
        _startTimer();
      }
    }
  }
}
