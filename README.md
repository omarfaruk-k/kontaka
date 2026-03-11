# Kontaka — Bangladeshi Banknote Recognition for Visually Impaired

Kontaka is a mobile-based assistive application that recognizes Bangladeshi banknotes using deep learning and announces the denomination through voice output.  
The system is designed to help visually impaired individuals independently identify paper currency using a smartphone camera.

---

## Features

- Real-time banknote recognition using device camera
- Lightweight MobileNetV2 deep learning model
- Offline inference using TensorFlow Lite
- Bangla voice feedback for visually impaired users
- No login or internet connection required

---

## System Overview

The system works through the following pipeline:

Camera Input → Image Preprocessing → Deep Learning Model (TFLite) → Prediction → Bangla Voice Output

---

## Dataset

A custom dataset was collected for training the model.

- Total Images: **17,836**
- Currency Classes: **15**
- Denominations: **9 Bangladeshi banknotes**

The dataset contains images captured under different:

- Lighting conditions
- Orientations
- Backgrounds

---

## Model

The recognition model is based on **MobileNetV2 with Transfer Learning**.

Key characteristics:

- Lightweight architecture optimized for mobile devices
- High accuracy with low computational cost
- Converted to **TensorFlow Lite** for mobile deployment

**Performance**

- Validation Accuracy: **99.89%**
- Average processing time: **~627 ms per frame**

---

## Mobile Application

The trained model is integrated into a Flutter Android application.

Workflow:

1. User opens the application
2. Camera captures the banknote image
3. Image is processed and passed to the TFLite model
4. Predicted denomination is announced through **Bangla voice output**

<!-- ---

## App Screenshots

<p align="center">
  <img src="assets/screenshots/home.png" width="250"/>
  <img src="assets/screenshots/scanning.png" width="250"/>
  <img src="assets/screenshots/result.png" width="250"/>
</p>

--- -->

## Installation

You can download and test the application from the **Releases section**.

APK Download:

https://github.com/omarfaruk-k/kontaka/releases/tag/v1.0

---


## License

This project is licensed under the **Creative Commons Attribution–NonCommercial 4.0 International License (CC BY-NC 4.0)**.

You are free to:

- Use
- Share
- Modify

Under the following conditions:

- Proper attribution must be given.
- **Commercial use is not permitted without explicit permission from the author.**

---