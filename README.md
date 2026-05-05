# PupillometryApp

iOS app for pupillometry measurements and ADHD diagnostic analysis using eye tracking and on-device machine learning.

## Overview

PupillometryApp captures pupil response from the front-facing camera, runs on-device ML models to estimate pupil size and detect eye landmarks, and applies an XGBoost classifier to produce ADHD-related signals from the resulting time series.

## Requirements

- macOS with Xcode 14.0+
- iOS 15.6+ device (real device required for camera)
- CocoaPods
- Python 3.9+ (only for the optional analysis tools / dashboard)

## Setup

```bash
git clone https://github.com/revathi-prasad/Pupl.git
cd Pupl/PupillometryApp
pod install
```

### Firebase configuration

Firebase is used for optional data storage. The real `GoogleService-Info.plist` is **not** committed.

1. Create a Firebase project at https://console.firebase.google.com
2. Add an iOS app with bundle ID matching the Xcode project.
3. Download `GoogleService-Info.plist` and place it at:
   ```
   PupillometryApp/PupillometryApp/GoogleService-Info.plist
   ```
   See `GoogleService-Info.plist.example` for the expected structure.

### Open and run

Always open the **workspace**, not the project file:

```bash
open PupillometryApp.xcworkspace
```

Select an iOS device, build and run (⌘R), and grant camera permission when prompted.

## Project layout

```
PupillometryApp/
├── PupillometryApp/
│   ├── Detection/    ML models for pupil detection and ADHD inference
│   ├── Core/         Data processing, privacy, performance monitoring
│   ├── Camera/       Camera capture and management
│   ├── UI/           View controllers and storyboards
│   └── Models/       CoreML .mlpackage model bundles
├── PupillometryAppTests/      Unit tests
├── PupillometryAppUITests/    UI tests
└── dashboard-python/          Optional Python analysis dashboard
```

### Key view controllers

- `WelcomeViewController` — entry point
- `CameraSetupViewController` — camera configuration
- `ADHDProtocolViewController` — main assessment flow
- `ResultsViewController` — assessment results

### ML models

- `left_eye.mlpackage` / `right_eye.mlpackage` — per-eye pupil detection
- `pupil_radius_cnn_50e.mlpackage` — pupil radius regression
- `xgb_model.mlpackage` — ADHD classification

Larger model artifacts are tracked via Git LFS — make sure `git lfs install` has been run before cloning.

## Optional: Python dashboard

```bash
pip install -r dashboard_requirements.txt
cd dashboard-python
python app.py
```

## Documentation

- `SETUP_INSTRUCTIONS.md` — extended setup notes
- `APP_FLOW_DOCUMENTATION.md` — end-to-end app flow
- `DETAILED_ARCHITECTURE.md` — module-level architecture
- `CODE_REFERENCE_GUIDE.md` — code map
- `PRIVACY_POLICY.md` / `APP_STORE_PRIVACY_LABELS.md` — privacy

## Troubleshooting

- **Build errors:** clean build folder (⇧⌘K) and rebuild
- **Pod issues:** `pod deintegrate && pod install`
- **Model loading errors:** confirm `.mlpackage` files are present and added to the app target

## License

See [LICENSE](LICENSE).

## Disclaimer

This software is for research and educational purposes and is **not** a medical device. It is not intended to diagnose, treat, cure, or prevent any disease.
