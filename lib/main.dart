import 'package:flutter/material.dart';

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
  
  @override
  void initState() {
    super.initState();
    // TODO: Initialize camera here
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // TODO: Add camera initialization logic
    // This is where you'll initialize the camera when app opens
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Upper Part - Live Camera Feed
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                color: Colors.grey[900],
                child: Stack(
                  children: [
                    // TODO: Replace this with actual camera preview
                    Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    // Camera preview will go here
                    // CameraPreview(_cameraController),
                    
                    // Top indicator
                    Positioned(
                      top: 16,
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
            ),
            
            // Lower Part - Detection Result Display
            Expanded(
              flex: 4,
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
                    // Visual indicator
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // TODO: Dispose camera controller
    super.dispose();
  }
}