Run flutter build ios --release --no-codesign
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Building com.example.dirBrowser for device (ios-release)...
Adding Swift Package Manager integration...                        23.8s
The following plugins do not support Swift Package Manager for ios:
  - flutter_background_service_ios
  - flutter_inappwebview_ios
  - flutter_local_notifications
  - media_kit_libs_ios_video
  - media_kit_video
  - permission_handler_apple
  - screen_brightness_ios
  - volume_controller
  - workmanager_apple
This will become an error in a future version of Flutter. Please contact the plugin maintainers to request Swift Package Manager adoption.
Running pod install...                                              4.4s
Running Xcode build...                                          
Xcode build done.                                           123.1s
Failed to build iOS app
Swift Compiler Error (Xcode): Cannot find 'TorrentPlugin' in scope
/Users/runner/work/ios2/ios2/ios/Runner/AppDelegate.swift:16:16

Encountered error while building for device.
Error: Process completed with exit code 1.