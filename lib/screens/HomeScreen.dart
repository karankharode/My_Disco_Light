import 'package:flutter/material.dart';
import 'package:screen/screen.dart';
import 'package:sensors/sensors.dart';
import 'package:torch_compat/torch_compat.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // color variables
  AnimationController _controller;
  Animatable<Color> background = TweenSequence<Color>([
    TweenSequenceItem(
      weight: 1.0,
      tween: ColorTween(
        begin: Colors.red,
        end: Colors.green,
      ),
    ),
    TweenSequenceItem(
      weight: 1.0,
      tween: ColorTween(
        begin: Colors.green,
        end: Colors.blue,
      ),
    ),
    TweenSequenceItem(
      weight: 1.0,
      tween: ColorTween(
        begin: Colors.blue,
        end: Colors.pink,
      ),
    ),
  ]);

  // noise variables
  bool _isRecording = false;
  StreamSubscription<NoiseReading> _noiseSubscription;
  NoiseMeter _noiseMeter;

  // shake variables
  bool _isSensingShake = false;
  StreamSubscription<AccelerometerEvent> _shakeSubscription;
  double shakeThresholdGravity = 1.3;
  int mShakeTimestamp = DateTime.now().millisecondsSinceEpoch;
  int mShakeCount = 0;
  final int shakeSlopTimeMS = 200;
  final int shakeCountResetTime = 1000;

  // brightness variables
  bool _isKeptOn = false;
  double _brightness = 0.5;

  @override
  void initState() {
    super.initState();
    // noise
    _noiseMeter = new NoiseMeter(onError);
    // brightness
    initPlatformState();
    // colors
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      animationBehavior: AnimationBehavior.preserve,
      vsync: this,
    );
  }

// Brightness Methods
  initPlatformState() async {
    bool keptOn = await Screen.isKeptOn;
    double brightness = await Screen.brightness;
    setState(() {
      _isKeptOn = keptOn;
      _brightness = brightness;
    });
  }
// Brightness Methods --end

// noise Methods
  flashWarning() async {
    TorchCompat.turnOn();
    await Future.delayed(Duration(milliseconds: 200));
    TorchCompat.turnOff();
    await Future.delayed(Duration(milliseconds: 200));
  }

  void onData(NoiseReading noiseReading) async {
    this.setState(() {
      if (!this._isRecording) {
        this._isRecording = true;
      }
    });
    // print(noiseReading.toString());
    print(noiseReading.meanDecibel);
    if (noiseReading.meanDecibel > 65) {
      TorchCompat.turnOn();
      await Future.delayed(Duration(milliseconds: 200));
      TorchCompat.turnOff();
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  void onError(PlatformException e) {
    print(e.toString());
    _isRecording = false;
  }

  void start() async {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);
      _controller.repeat();
    } catch (err) {
      print(err);
    }
  }

  void stop() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription.cancel();
        _noiseSubscription = null;
      }
      this.setState(() {
        this._isRecording = false;
      });
      _controller.stop();
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  Widget getContent() {
    return Container(
        margin: EdgeInsets.all(25),
        child: Column(children: [
          Container(
            child: Text(_isRecording ? "Mic: ON" : "Mic: OFF",
                style: TextStyle(fontSize: 25, color: Colors.blue)),
            margin: EdgeInsets.only(top: 20),
          )
        ]));
  }
// noise Methods -- end

// Shake Methods
  void startSensingShake() async {
    this.setState(() {
      if (!this._isSensingShake) {
        this._isSensingShake = true;
      }
    });
    print("Entered Shake Zone");
    try {
      _shakeSubscription =
          accelerometerEvents.listen((AccelerometerEvent event) {
        double x = event.x;
        double y = event.y;
        double z = event.z;

        double gX = x / 9.80665;
        double gY = y / 9.80665;
        double gZ = z / 9.80665;

        // gForce will be close to 1 when there is no movement.
        double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);
        print(gForce);

        if (gForce > shakeThresholdGravity) {
          var now = DateTime.now().millisecondsSinceEpoch;
          // ignore shake events too close to each other (200ms)
          if (mShakeTimestamp + shakeSlopTimeMS > now) {
            return;
          }
          // reset the shake count after 1 seconds of no shakes
          if (mShakeTimestamp + shakeCountResetTime < now) {
            mShakeCount = 0;
          }
          mShakeTimestamp = now;
          mShakeCount++;
          for (int i = 0; i < 5; i++) {
            shakeFlashWarning();
          }
        }
      });
    } catch (err) {
      print(err);
    }
  }

  void stopSensingShake() async {
    print("No Shake Zone....");
    try {
      _shakeSubscription.cancel();
      this.setState(() {
        this._isSensingShake = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  shakeFlashWarning() async {
    TorchCompat.turnOn();
    await Future.delayed(Duration(milliseconds: 100));
    TorchCompat.turnOff();
    await Future.delayed(Duration(milliseconds: 100));
  }
// Shake Methods  -- end

  @override
  Widget build(BuildContext context) {
    
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Scaffold(
              appBar: AppBar(
                title: const Text('Trippy Disco Lights'),
              ),
              body: Container(
                color: background
                    .evaluate(AlwaysStoppedAnimation(_controller.value)),
                child: Center(
                  child: Column(
                    children: <Widget>[
                      getContent(),
                      RaisedButton(
                          child: Text('Turn on Flash'),
                          onPressed: () {
                            TorchCompat.turnOn();
                          }),
                      RaisedButton(
                          child: Text('Turn off Flash'),
                          onPressed: () {
                            TorchCompat.turnOff();
                          }),
                      RaisedButton(
                          child: Text('Disco Light Baby !'),
                          onPressed: () async {
                            // isBlinking = !isBlinking;
                            for (int i = 0; i < 6; i++) {
                              TorchCompat.turnOn();
                              await Future.delayed(Duration(milliseconds: 200));
                              TorchCompat.turnOff();
                              await Future.delayed(Duration(milliseconds: 200));
                            }
                          }),
                      new Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // new Text("Screen is kept on ? "),
                            // new Checkbox(
                            //     value: _isKeptOn,
                            //     onChanged: (bool b) {
                            //       Screen.keepOn(b);
                            //       setState(() {
                            //         _isKeptOn = b;
                            //       });
                            //     })
                          ]),
                      new Text("Brightness :"),
                      // new Slider(
                      //     value: _brightness,
                      //     onChanged: (double b) {
                      //       setState(() {
                      //         _brightness = b;
                      //       });

                      //       Screen.setBrightness(b);
                      //     })
                    ],
                  ),
                ),
              ),
              floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                      backgroundColor:
                          _isSensingShake ? Colors.red : Colors.green,
                      onPressed: _isSensingShake
                          ? stopSensingShake
                          : startSensingShake,
                      child: _isSensingShake
                          ? Icon(Icons.stop)
                          : Icon(Icons.vibration)),
                  SizedBox(
                    height: 10,
                  ),
                  FloatingActionButton(
                      backgroundColor: _isRecording ? Colors.red : Colors.green,
                      onPressed: _isRecording ? stop : start,
                      child: _isRecording ? Icon(Icons.stop) : Icon(Icons.mic)),
                ],
              ));
        });
  }

  @override
  void dispose() {
    // Mandatory for Camera 1 on Android
    TorchCompat.dispose();
    _noiseSubscription.cancel();
    _shakeSubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
