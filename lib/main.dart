import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
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
  String detectedCurrency = "No note detected";
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  // TFLite variables
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  // Processing control
  bool _isProcessing = false;
  DateTime _lastProcessTime = DateTime.now();
  final int _processingInterval = 500; // Process every 500ms
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  // Load TFLite model and labels
  Future<void> _loadModel() async {
    try {
      // Load the model
      _interpreter = await Interpreter.fromAsset('assets/currency_model.tflite');
      print('✅ Model loaded successfully');
      
      // Load labels
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
          ResolutionPreset.medium, // Use medium for better performance
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
          
          // Start processing frames
          _startImageStream();
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // Start processing camera frames
  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) {
      // Time-based control: Only process if 500ms have passed
      final now = DateTime.now();
      final timeSinceLastProcess = now.difference(_lastProcessTime).inMilliseconds;
      
      if (timeSinceLastProcess < _processingInterval) {
        return; // Skip this frame
      }
      
      // Flag-based control: Only process if not already processing
      if (_isProcessing) {
        return; // Skip this frame
      }
      
      // Process this frame
      _isProcessing = true;
      _lastProcessTime = now;
      _processImage(image);
    });
  }

  // Process camera image
  Future<void> _processImage(CameraImage image) async {
    try {
      if (_interpreter == null) {
        _isProcessing = false;
        return;
      }

      // Convert CameraImage to image format
      final img.Image? convertedImage = _convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      // Resize to 224x224 (model input size)
      final img.Image resizedImage = img.copyResize(
        convertedImage,
        width: 224,
        height: 224,
      );

      // Preprocess: normalize to [-1, 1] (MobileNetV2 preprocessing)
      final input = _preprocessImage(resizedImage);

      // Prepare output buffer
      var output = List.filled(1 * 9, 0.0).reshape([1, 9]);

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction
      final probabilities = output[0] as List<double>;
      final maxIndex = probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b));
      final confidence = probabilities[maxIndex];

      // Update UI only if confidence is good
      if (confidence > 0.8) { // 60% confidence threshold
        if (mounted) {
          setState(() {
            detectedCurrency = _labels[maxIndex];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            detectedCurrency = "No note detected";
          });
        }
      }

    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // Convert CameraImage to img.Image
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

  // Convert YUV420 to RGB
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

  // Convert BGRA8888 to RGB
  img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  // Preprocess image: normalize to [-1, 1]
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
        
        // Normalize from [0, 255] to [-1, 1] (MobileNetV2 preprocessing)
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
      body: Column(
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
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hold currency note in frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                    const Text(
                      'Detected:',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
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
                              : Colors.green[700],
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
                            : Colors.green[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}