# Pubspec Updates for Weekend Mingle App

To implement the video and voice call functionality, you need to add the Agora SDK dependency to your pubspec.yaml file. Follow these steps:

1. Open your `pubspec.yaml` file
2. Add the following dependency under the dependencies section:

```yaml
  agora_rtc_engine: ^6.2.6
```

3. Run the following command to install the dependency:

```bash
flutter pub get
```

## Android Configuration for Agora

Add the following permissions to your `android/app/src/main/AndroidManifest.xml` file if they're not already there:

```xml
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

## iOS Configuration for Agora

Add the following to your `ios/Runner/Info.plist` file:

```xml
<key>NSCameraUsageDescription</key>
<string>We need access to your camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice and video calls</string>
```

## Getting an Agora App ID

To use Agora services, you need to:

1. Create an account on [Agora.io](https://www.agora.io/)
2. Create a new project in the Agora Console
3. Get the App ID from your project
4. Replace the placeholder in the `call_service.dart` file:

```dart
// Replace this line in call_service.dart
static const String appId = 'YOUR_AGORA_APP_ID';

// With your actual App ID
static const String appId = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
```

Make sure to keep your App ID secure and not commit it directly to version control. Consider using environment variables or a secure configuration approach for production.