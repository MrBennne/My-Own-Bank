---
name: flutter-build
description: Build Flutter release APK and deploy to Google Drive
disable-model-invocation: true
---

# Flutter Build & Deploy

Builds a Flutter release APK and automatically copies it to Google Drive.

## Usage

```
/flutter-build
```

## What it does

1. **Build**: Runs `flutter build apk --release` in the mobile directory
2. **Verify**: Checks APK size and confirms successful build
3. **Deploy**: Copies APK to `G:/Mit drev/Finans/app-release.apk`
4. **Log**: Displays build output and deployment status

## Requirements

- Flutter SDK installed and configured
- Google Drive mounted as network drive (G:)
- Access to banking/mobile/ directory

## Output

Displays:
- Build time
- APK filename and size
- Deployment status
- Direct path to deployed APK

## When to use

- After implementing new features
- Before releasing updates to users
- When running Phase 1 feature builds
