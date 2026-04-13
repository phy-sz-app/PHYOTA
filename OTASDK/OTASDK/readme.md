cd /Users/dilu/SourceTree/ios_ota/OTASDK

xcodebuild archive -project 'OTASDK.xcodeproj' -scheme 'OTASDK' -configuration Release -destination 'generic/platform=iOS' -archivePath '/Users/dilu/Desktop/archives/OTASDK.framework-iphoneos.xcarchive' SKIP_INSTALL=NO


xcodebuild archive -project 'OTASDK.xcodeproj' -scheme 'OTASDK' -configuration Release -destination 'generic/platform=iOS Simulator' -archivePath '/Users/dilu/Desktop/archives/OTASDK.framework-iphonesimulator.xcarchive' SKIP_INSTALL=NO


xcodebuild -create-xcframework -framework '/Users/dilu/Desktop/archives/OTASDK.framework-iphoneos.xcarchive/Products/Library/Frameworks/OTASDK.framework' -framework '/Users/dilu/Desktop/archives/OTASDK.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/OTASDK.framework'  -output '/Users/dilu/Desktop/archives/OTASDK.xcframework' 
