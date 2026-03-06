import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kuntaka',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const CurrencyDetectorHome(),
    );
  }
}

class CurrencyDetectorHome extends StatefulWidget {
  const CurrencyDetectorHome({super.key});

  @override
  State<CurrencyDetectorHome> createState() => _CurrencyDetectorHomeState();
}

class _CurrencyDetectorHomeState extends State<CurrencyDetectorHome>
    with WidgetsBindingObserver {
  String detectedCurrency = "No note detected";
  String statusMessage = "স্ক্রিনে চাপ দিয়ে ধরুন";
  bool isPressing = false;
  bool isResultLocked = false;
  double currentConfidence = 0.0;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  Interpreter? _interpreter;
  List<String> _labels = [];

  bool _isProcessing = false;
  final int _requiredConsecutiveMatches = 3;
  final double _confidenceThreshold = 0.40;
  bool _hasPredictedThisPress = false;

  DateTime? _pressStartTime;

  final FlutterTts _flutterTts = FlutterTts();
  bool _hasSpoken = false;
  bool _readyToScan = false;

  Timer? _resultClearTimer;

  bool _welcomeSpoken = false;

  final bool _debugMode = true;

  final Map<String, String> _labelMap = {
    '1000_tk_v1': '১০০০ টাকা',
    '1000_tk_v2': '১০০০ টাকা',
    '100_tk': '১০০ টাকা',
    '10_tk': '১০ টাকা',
    '200_tk': '২০০ টাকা',
    '20_tk_v1': '২০ টাকা',
    '20_tk_v2': '২০ টাকা',
    '2_tk_v1': '২ টাকা',
    '2_tk_v2': '২ টাকা',
    '500_tk': '৫০০ টাকা',
    '50_tk_v1': '৫০ টাকা',
    '50_tk_v2': '৫০ টাকা',
    '50_tk_v3': '৫০ টাকা',
    '5_tk_v1': '৫ টাকা',
    '5_tk_v2': '৫ টাকা',
  };

  @override
  void initState() {
    super.initState();
    // Register this widget as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _loadModel();
    _initializeTts();
  }

  // ─── LIFECYCLE OBSERVER (Problem 2 fix) ───────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // App going to background — stop and release camera
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground — reinitialize camera
      _initializeCamera();
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
      } catch (e) {
        print('Error stopping camera: $e');
      } finally {
        _cameraController = null;
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      }
    }
  }

  // ─── CAMERA INIT ──────────────────────────────────────────────────────────

  Future<void> _initializeCamera() async {
    try {
      _cameras ??= await availableCameras();

      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });

          _startImageStream();

          // Speak welcome message once per session after camera is ready
          if (!_welcomeSpoken) {
            _welcomeSpoken = true;
            // Small delay so TTS doesn't fire before everything loads
            Future.delayed(const Duration(milliseconds: 800), () {
              _speakWelcome();
            });
          }
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) {
      if (!isPressing || !_readyToScan || _hasPredictedThisPress) return;
      if (_isProcessing) return;

      if (_pressStartTime == null) return;
      final holdDuration =
          DateTime.now().difference(_pressStartTime!).inMilliseconds;
      if (holdDuration < 100) return;

      _isProcessing = true;
      _processImage(image);
    });
  }

  // ─── TTS ──────────────────────────────────────────────────────────────────

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("bn-BD");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      print('✅ TTS initialized');
    } catch (e) {
      print('❌ Error initializing TTS: $e');
    }
  }

  Future<void> _speakWelcome() async {
    try {
      // "Hold a note in front of the camera and press the screen"
      await _flutterTts.speak("ক্যামেরার সামনে নোট ধরুন এবং স্ক্রিনে চাপ দিন");
    } catch (e) {
      print('❌ Error speaking welcome: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      if (!_hasSpoken) {
        await _flutterTts.speak(text);
        _hasSpoken = true;
        print('🔊 Speaking: $text');
      }
    } catch (e) {
      print('❌ Error speaking: $e');
    }
  }

  // ─── MODEL ────────────────────────────────────────────────────────────────

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/currency_model_final.tflite',
      );
      print('✅ Model loaded successfully');

      _labels = [
        '1000_tk_v1', // index 0
        '1000_tk_v2', // index 1
        '100_tk', // index 2
        '10_tk', // index 3
        '200_tk', // index 4
        '20_tk_v1', // index 5
        '20_tk_v2', // index 6
        '2_tk_v1', // index 7
        '2_tk_v2', // index 8
        '500_tk', // index 9
        '50_tk_v1', // index 10
        '50_tk_v2', // index 11
        '50_tk_v3', // index 12
        '5_tk_v1', // index 13
        '5_tk_v2', // index 14
      ];
      print('✅ Labels loaded: ${_labels.length} classes');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  // ─── IMAGE PROCESSING ─────────────────────────────────────────────────────

  Future<void> _processImage(CameraImage image) async {
      final stopwatch = Stopwatch()..start();
    try {
      if (_interpreter == null) {
        _isProcessing = false;
        return;
      }

      final img.Image? convertedImage = _convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      final img.Image resizedImage = img.copyResize(
        convertedImage,
        width: 224,
        height: 224,
      );
      final input = _preprocessImage(resizedImage);
      var output = List.filled(1 * 15, 0.0).reshape([1, 15]);
      _interpreter!.run(input, output);
      final probabilities = output[0] as List<double>;
      final maxIndex = probabilities.indexOf(
        probabilities.reduce((a, b) => a > b ? a : b),
      );
      final confidence = probabilities[maxIndex];
      final String rawLabel = _labels[maxIndex];
      final String predictedLabel = _labelMap[rawLabel] ?? rawLabel;

      print('--- FRAME ---');
      for (int i = 0; i < _labels.length; i++) {
        print(
          '  ${_labels[i]}: ${(probabilities[i] * 100).toStringAsFixed(2)}%',
        );
      }
      print(
        '  ✅ TOP: $rawLabel → $predictedLabel (${(confidence * 100).toStringAsFixed(2)}%)',
      );

      if (confidence >= _confidenceThreshold) {
        _hasPredictedThisPress = true;

        // Cancel any existing clear timer (user pressed before it expired)
        _resultClearTimer?.cancel();

        HapticFeedback.mediumImpact();

        if (mounted) {
          setState(() {
            detectedCurrency = predictedLabel;
            currentConfidence = confidence;
            isResultLocked = true;
            statusMessage = "Release to scan again";
          });
        }

        await _speak(predictedLabel);

        // Start 4-second auto-clear timer (Problem 1)
        _startResultClearTimer();
      } else {
        if (mounted) {
          setState(() {
            statusMessage = "সঠিকভাবে ধরুন";
            currentConfidence = confidence;
          });
        }
      }
    } catch (e) {
      print('❌ Error: $e');
    } finally {
      stopwatch.stop();
      print('⏱ Total processing time: ${stopwatch.elapsedMilliseconds}ms');
      _isProcessing = false;

    }
  }

  // ─── AUTO-CLEAR TIMER (Problem 1) ─────────────────────────────────────────

  void _startResultClearTimer() {
    _resultClearTimer?.cancel();
    _resultClearTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !isPressing) {
        // Only clear if user is not actively pressing
        setState(() {
          detectedCurrency = "No note detected";
          currentConfidence = 0.0;
          isResultLocked = false;
          statusMessage = "স্ক্রিনে চাপ দিয়ে ধরুন";
        });
        print('⏱ Result auto-cleared after 4 seconds');
      }
    });
  }

  // ─── PRESS HANDLERS ───────────────────────────────────────────────────────

  void _onPressStart() {
    HapticFeedback.lightImpact();

    // Cancel auto-clear timer — user is starting a new scan
    _resultClearTimer?.cancel();

    setState(() {
      isPressing = true;
      isResultLocked = false;
      _hasPredictedThisPress = false;
      _hasSpoken = false;
      _readyToScan = false;
      statusMessage = "ধরে রাখুন...";
      _pressStartTime = DateTime.now();
    });

    Future.delayed(const Duration(milliseconds:10), () {
      if (isPressing && mounted) {
        setState(() {
          _readyToScan = true;
          statusMessage = "স্ক্যান হচ্ছে...";
        });
      }
    });
  }

  void _onPressEnd() {
    setState(() {
      isPressing = false;
      _readyToScan = false;
      _hasPredictedThisPress = false;
      _hasSpoken = false;

      if (!isResultLocked) {
        statusMessage = "স্ক্রিনে চাপ দিয়ে ধরুন";
      } else {
        statusMessage = "স্ক্রিনে চাপ দিয়ে ধরুন";
      }
    });
  }

  // ─── IMAGE CONVERSION ─────────────────────────────────────────────────────

  img.Image? _convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(image);
      }
      return null;
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img.Image convertedImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        convertedImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return convertedImage;
  }

  img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(224, (_) => List.filled(3, 0.0)),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixel(x, y);
        input[0][y][x][0] = (pixel.r / 127.5) - 1.0;
        input[0][y][x][1] = (pixel.g / 127.5) - 1.0;
        input[0][y][x][2] = (pixel.b / 127.5) - 1.0;
      }
    }

    return input;
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _onPressStart(),
        onTapUp: (_) => _onPressEnd(),
        onTapCancel: () => _onPressEnd(),
        child: Column(
          children: [
            // Upper Part — Live Camera Feed
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  // Camera preview
                  SizedBox.expand(
                    child:
                        _isCameraInitialized && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : Container(
                              color: Colors.black,
                              child: Center(
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                  ),

                  // Scanning border overlay (when pressing)
                  if (isPressing && !isResultLocked)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 4),
                      ),
                    ),

                  // Success overlay (when result locked)
                  if (isResultLocked)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 6),
                      ),
                    ),

                  // Top status text
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            color:
                                isResultLocked
                                    ? Colors.greenAccent
                                    : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lower Part — Detection Result Display
            Expanded(
              flex: 4,
              child: SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Detected:',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (isResultLocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          detectedCurrency,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color:
                                detectedCurrency == "No note detected"
                                    ? Colors.grey[400]
                                    : isResultLocked
                                    ? Colors.green[700]
                                    : Colors.green[500],
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              detectedCurrency == "No note detected"
                                  ? Colors.grey[300]
                                  : isResultLocked
                                  ? Colors.green[700]
                                  : Colors.green[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (_debugMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${(currentConfidence * 100).toStringAsFixed(1)}% confidence',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DISPOSE ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resultClearTimer?.cancel();
    _cameraController?.dispose();
    _interpreter?.close();
    _flutterTts.stop();
    super.dispose();
  }
}
