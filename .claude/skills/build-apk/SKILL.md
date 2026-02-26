---
name: build-apk
description: Build Flutter release APK and copy to Google Drive sync folder
disable-model-invocation: true
---

# Build APK

Build the Flutter release APK and deploy it to the shared drive.

## Steps

1. Navigate to the `mobile/` directory
2. Run `flutter build apk --release`
3. Verify the APK was created at `mobile/build/app/outputs/flutter-apk/app-release.apk`
4. Copy to `G:\Mit drev\Finans\app-release.apk`
5. Report: build status, file size, output path
