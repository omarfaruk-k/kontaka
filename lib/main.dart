import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:typed_data';

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

class _CurrencyDetectorHomeState extends State<CurrencyDetectorHome> {
  // UI State
  String detectedCurrency = "No note detected";
  String statusMessage = "Press and hold anywhere to detect";
  bool isPressing = false;
  bool isResultLocked = false;
  double currentConfidence = 0.0;
  
  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  // TFLite
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  // Processing Control - TUNABLE VALUES
  bool _isProcessing = false;
  DateTime _lastProcessTime = DateTime.now();
  final int _processingInterval = 300; // 300ms between frames
  final int _requiredConsecutiveMatches = 3; // Need 3 same results
  final double _confidenceThreshold = 0.80; // 80% confidence to lock
  final int _timeoutSeconds = 10; // Show help after 10 seconds
  
  // Stability Tracking
  final List<String> _recentPredictions = [];
  final List<double> _recentConfidences = [];
  DateTime? _pressStartTime;
  
  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _hasSpoken = false;
  
  // Debug mode
  final bool _debugMode = true; // Set to false for production

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      print('✅ TTS initialized');
    } catch (e) {
      print('❌ Error initializing TTS: $e');
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

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/currency_model.tflite');
      print('✅ Model loaded successfully');
      
      _labels = [
        '10 Taka',
        '100 Taka',
        '1000 Taka',
        '2 Taka',
        '20 Taka',
        '200 Taka',
        '5 Taka',
        '50 Taka',
        '500 Taka'
      ];
      print('✅ Labels loaded: ${_labels.length} classes');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
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
          
          // Start camera stream (always running, but only process when pressing)
          _startImageStream();
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
      // Only process if user is pressing AND result not locked
      if (!isPressing || isResultLocked) {
        return;
      }
      
      // Check timeout
      if (_pressStartTime != null) {
        final holdDuration = DateTime.now().difference(_pressStartTime!).inSeconds;
        if (holdDuration >= _timeoutSeconds && !isResultLocked) {
          if (mounted) {
            setState(() {
              statusMessage = "Try better lighting or hold note flatter";
            });
          }
        }
      }
      
      // Time-based control
      final now = DateTime.now();
      final timeSinceLastProcess = now.difference(_lastProcessTime).inMilliseconds;
      
      if (timeSinceLastProcess < _processingInterval) {
        return;
      }
      
      // Flag-based control
      if (_isProcessing) {
        return;
      }
      
      _isProcessing = true;
      _lastProcessTime = now;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
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
      var output = List.filled(1 * 9, 0.0).reshape([1, 9]);

      _interpreter!.run(input, output);

      final probabilities = output[0] as List<double>;
      final maxIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));
      final confidence = probabilities[maxIndex];
      final predictedLabel = _labels[maxIndex];

      if (mounted) {
        setState(() {
          currentConfidence = confidence;
        });
      }

      // Confidence-based processing
      if (confidence >= _confidenceThreshold) {
        // High confidence - add to recent predictions
        _recentPredictions.add(predictedLabel);
        _recentConfidences.add(confidence);
        
        // Keep only last required matches
        if (_recentPredictions.length > _requiredConsecutiveMatches) {
          _recentPredictions.removeAt(0);
          _recentConfidences.removeAt(0);
        }
        
        // Check for consistency
        if (_recentPredictions.length >= _requiredConsecutiveMatches) {
          final firstPrediction = _recentPredictions[0];
          final allMatch = _recentPredictions.every((p) => p == firstPrediction);
          
          if (allMatch) {
            // LOCK RESULT!
            final avgConfidence = _recentConfidences.reduce((a, b) => a + b) / _recentConfidences.length;
            
            // Haptic feedback - success vibration
            HapticFeedback.mediumImpact();
            
            if (mounted) {
              setState(() {
                detectedCurrency = firstPrediction;
                isResultLocked = true;
                statusMessage = "✓ Result confirmed! Release to scan again";
                currentConfidence = avgConfidence;
              });
            }
            
            // Speak the result
            _speak(firstPrediction);
            
            print('🔒 LOCKED: $firstPrediction (${(avgConfidence * 100).toStringAsFixed(1)}%)');
          } else {
            // Not all match, keep scanning
            if (mounted) {
              setState(() {
                statusMessage = "Scanning... Hold steady";
              });
            }
          }
        } else {
          // Still collecting predictions
          if (mounted) {
            setState(() {
              statusMessage = "Scanning... (${_recentPredictions.length}/$_requiredConsecutiveMatches)";
            });
          }
        }
      } else if (confidence >= 0.60) {
        // Medium confidence - clear recent and ask to hold steady
        _recentPredictions.clear();
        _recentConfidences.clear();
        if (mounted) {
          setState(() {
            statusMessage = "Hold steady";
          });
        }
      } else {
        // Low confidence
        _recentPredictions.clear();
        _recentConfidences.clear();
        if (mounted) {
          setState(() {
            statusMessage = "No clear note detected";
          });
        }
      }

    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // Handle press start
  void _onPressStart() {
    // Light haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      isPressing = true;
      isResultLocked = false;
      _recentPredictions.clear();
      _recentConfidences.clear();
      _hasSpoken = false;
      statusMessage = "Scanning...";
      _pressStartTime = DateTime.now();
    });
    
    print('👆 Press started');
  }

  // Handle press end
  void _onPressEnd() {
    setState(() {
      isPressing = false;
      _pressStartTime = null;
      
      // Keep last result visible
      if (!isResultLocked) {
        statusMessage = "Press and hold anywhere to detect";
        // Don't reset detectedCurrency - keep last result visible
      }
    });
    
    print('👆 Press ended');
  }

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
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
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
        (_) => List.generate(
          224,
          (_) => List.filled(3, 0.0),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Detect press and hold anywhere on screen
        onTapDown: (_) => _onPressStart(),
        onTapUp: (_) => _onPressEnd(),
        onTapCancel: () => _onPressEnd(),
        child: Column(
          children: [
            // Upper Part - Live Camera Feed
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  // Camera preview
                  SizedBox.expand(
                    child: _isCameraInitialized && _cameraController != null
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
                      duration: Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green,
                          width: 4,
                        ),
                      ),
                    ),
                  
                  // Success overlay (when locked)
                  if (isResultLocked)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green,
                          width: 6,
                        ),
                      ),
                    ),
                  
                  // Top instruction text
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
                            color: isResultLocked ? Colors.greenAccent : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  // Debug info (top right)
                  if (_debugMode)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Confidence: ${(currentConfidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'Matches: ${_recentPredictions.length}/$_requiredConsecutiveMatches',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Lower Part - Detection Result Display
            Expanded(
              flex: 4,
              child: SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
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
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
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
                            color: detectedCurrency == "No note detected"
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
                          color: detectedCurrency == "No note detected"
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
                            style: TextStyle(
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

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    _flutterTts.stop();
    super.dispose();
  }
}