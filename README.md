# VJ Fit

A workout and vegetarian diet app for Android and the browser (iOS-ready), built with Flutter.

## Features

- **Today**: the day's workout from your active plan, with warm-up, workout and cool-down. Tap a set to tick it and start the rest timer. Press and hold a set to log weight and reps.
- **Workouts**: create and edit weekly plans. Browse 880 exercises with start and finish photos, muscles worked, steps and a demo video link. Add your own exercises with your own photos.
- **Diet**: vegetarian diet plans with calories, protein, carbs and fat. Tick meals as you eat them, add extra food, and track water. Create your own diet plans and foods (110 Indian vegetarian foods built in).
- **Me**: daily calorie and protein targets from your age, height, weight, activity and goal. Workout history. Backup and restore.

All data is stored on the phone, or in the browser for the web version. Nothing is sent online.

## Get the APK

Every push to `main` builds a new APK with GitHub Actions. Download `VJ-Fit.apk` from the latest release on the **Releases** page and open it on an Android phone.

## Use it in a browser (iPhone, laptop)

Every push to `main` also publishes the web version to GitHub Pages:
**https://vijaythapak.github.io/vj-fitness/**

On an iPhone, open it in Safari, tap **Share → Add to Home Screen**, and open VJ Fit from the new icon.
Data is kept in that browser only, so use **Me → Save backup** to move it to another device.

## Build locally

```bash
flutter create --org com.vjfit --project-name vj_fit --platforms android,ios,web .
python3 tool/setup_platforms.py
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Signing key

`tool/vjfit-release.jks` signs the APK (v1 + v2 + v3 signatures) so updates install over older versions.
This repo is public, so anyone can see that key. Before publishing on the Play Store, create a private key
and store it as the `KEYSTORE_B64` repository secret (base64 of a PKCS12 keystore, alias `vjfit`,
password `vjfitapp`). The build uses the secret when it is set.

## Credits

Exercise photos and instructions: [Free Exercise DB](https://github.com/yuhonas/free-exercise-db) (public domain). Food values are approximate.
