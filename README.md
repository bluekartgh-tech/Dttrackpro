# DTTrack Pro – GPS Tracking Android App

Flutter mobile app for **DTTrack Pro** that connects to your GPSWOX-compatible backend at `https://app.dttrack.com`.

## Features (matching your UI designs)

| Screen | Status |
|--------|--------|
| 1. Splash | ✅ |
| 2. Login | ✅ (pre-filled with harry / 1234512345 for testing) |
| 3. Dashboard | ✅ Total / Online / Offline / Idle + stats |
| 4. Live Map (All Vehicles) | ✅ flutter_map + markers by status |
| 5. Live Tracking (Vehicle Detail) | ✅ |
| 6. Vehicles List | ✅ filters Online / Offline / Idle |
| 7. Vehicle Details | ✅ sensors, status, Live Tracking button |
| 8. History / Playback | ✅ timeline + map polyline |
| 9. Alerts / Events | ✅ live events from API |
| 10. Geofences | ✅ list from API |
| 11. Commands | ✅ GPRS templates (Engine On/Off etc.) |
| 12. Reports | ✅ placeholder + link to generate |
| 13. Profile / Settings | ✅ |
| 14. App Sidebar / More menu | ✅ |

## API Integration (real endpoints)

- `POST /api/login` → `user_api_hash`
- `GET /api/get_devices`
- `GET /api/get_devices_latest`
- `GET /api/get_user_data`
- `GET /api/get_events`
- `GET /api/get_alerts`
- `GET /api/get_geofences`
- `GET /api/get_history` (from_date, from_time, to_date, to_time)
- `GET /api/send_command_data`
- `POST /api/send_command`

All authenticated calls append `?user_api_hash=...`

## Build Debug APK (on your machine)

### Prerequisites
- Flutter 3.22+ (https://docs.flutter.dev/get-started/install)
- Android Studio or Android SDK + cmdline-tools
- Java 17 recommended

### Steps

```bash
# 1. Unzip / open this project
cd dttrack_pro

# 2. Get dependencies
flutter pub get

# 3. (Optional) Accept Android licenses
flutter doctor --android-licenses

# 4. Build debug APK
flutter build apk --debug

# Output:
# build/app/outputs/flutter-apk/app-debug.apk
```

Install on device:

```bash
flutter install
# or
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Run on emulator / device

```bash
flutter run
```

## Default test credentials (already filled in Login screen)

- **Email / User ID**: `harry`
- **Password**: `1234512345`

## Project structure

```
lib/
  main.dart
  models/device.dart
  services/api_service.dart      ← all GPSWOX API calls
  providers/app_provider.dart    ← state management
  screens/
    splash_screen.dart
    login_screen.dart
    home_shell.dart              ← bottom navigation
    dashboard_screen.dart
    live_map_screen.dart
    vehicles_screen.dart
    vehicle_detail_screen.dart
    history_screen.dart
    alerts_screen.dart
    commands_screen.dart
    more_screen.dart
  utils/theme.dart               ← green brand colors matching design
```

## Notes

- Maps use **flutter_map** (OpenStreetMap tiles) so no Google Maps API key is required for basic use.
- If you want Google Maps, replace with `google_maps_flutter` and add your API key in `android/app/src/main/AndroidManifest.xml`.
- Live refresh: pull-to-refresh on Dashboard / Vehicles / Map.
- Commands support the GPRS templates returned by the server (Engine On / Engine Off, etc.).

## Next improvements you can add

- Real-time polling every 10–15 s on Live Map
- Push notifications (FCM)
- Geofence drawing on map
- Full report generation & PDF export
- Offline caching of last positions

---

Built for **app.dttrack.com** · GPSWOX-compatible API
