Run flutter build ios --release --no-codesign
  
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Xcode is fetching Swift Package Manager dependencies. This may take several minutes...
  Fetching from https://github.com/krzyzanowskim/OpenSSL.git (cached)...     
Building com.example.dirBrowser for device (ios-release)...
Adding Swift Package Manager integration...                        30.7s
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
Running pod install...                                              7.0s
Running Xcode build...                                          
Xcode build done.                                           255.8s
Failed to build iOS app
Swift Compiler Error (Xcode): Cannot assign value of type 'URL' to type 'String'
/Users/runner/work/ios2/ios2/ios/Runner/TorrentManager.swift:35:32
Swift Compiler Error (Xcode): Cannot assign value of type 'URL' to type 'String'
/Users/runner/work/ios2/ios2/ios/Runner/TorrentManager.swift:36:32
Swift Compiler Error (Xcode): Cannot assign value of type 'URL' to type 'String'
/Users/runner/work/ios2/ios2/ios/Runner/TorrentManager.swift:37:34
Encountered error while building for device.
Error: Process completed with exit code 1.