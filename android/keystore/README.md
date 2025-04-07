# Keystore Information

This directory contains the keystore file used for signing the release build of the Weekend Mingle app.

## Release Keystore

The release keystore file (`release-keystore.jks`) should be placed in this directory. This file is used for signing the release build of the app for Play Store submission.

## Important Notes

- **DO NOT commit the actual keystore file to version control**
- Keep the keystore file and passwords in a secure location
- The keystore information is configured in `android/app/build.gradle`

## Generating a Keystore

If you need to generate a new keystore, you can use the following command:

```
keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias weekendmingle
```

When prompted, use the password specified in the `build.gradle` file.