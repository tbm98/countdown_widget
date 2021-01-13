# countdown_widget

A package timer works correctly even if the app is locked [issue](https://github.com/flutter/flutter/issues/25435)

## Getting Started

```dart
Scaffold(
      body: Center(
        child: CountDownWidget(
          duration: Duration(seconds: 20),
          builder: (context, duration) {
            return Text(duration.inSeconds.toString());
          },
          onDurationRemainChanged: (duration) {
            print('duration:${duration.toString()}');
          },
        ),
      ),
)
```
