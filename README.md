# OTASDK

[![CocoaPods](https://img.shields.io/cocoapods/v/OTASDK.svg)](https://cocoapods.org/pods/OTASDK)
[![CocoaPods](https://img.shields.io/cocoapods/p/OTASDK.svg)](https://cocoapods.org/pods/OTASDK)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/phy-sz-app/OTASDK/blob/master/LICENSE)

A Bluetooth Low Energy (BLE) Over-The-Air (OTA) firmware update SDK for PHY devices.

## Requirements

- iOS 12.0+
- Xcode 12.0+
- Swift 5.0+ or Objective-C

## Installation

### CocoaPods

OTASDK is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'OTASDK', '~> 1.0.0'
```

Then run:

```bash
pod install
```

### Manual Installation

1. Drag the `OTASDK` folder into your Xcode project.
2. Make sure "Copy items if needed" is selected.
3. Add `CoreBluetooth` and `UIKit` frameworks to your target's "Linked Frameworks and Libraries".

## Usage

### Import

**Objective-C:**
```objective-c
#import <OTASDK/OTASDK.h>
```

**Swift:**
```swift
import OTASDK
```

### Basic Example

```objective-c
#import <OTASDK/OTASDK.h>

// Initialize BLE manager
PHYBLEManager *bleManager = [[PHYBLEManager alloc] init];

// Start scanning for devices
[bleManager startScan];

// Connect to a device
// [bleManager connectToDevice:device];

// Perform OTA update
// [bleManager startOTAUpdateWithFileData:fileData];
```

## API Documentation

### PHYBLEManager
Main class for BLE operations and OTA updates.

### PHYBLEModel
Model class representing BLE device information.

### JCDataConvert
Utility class for data conversion between hex strings and NSData.

### PHYOTAType
Type definitions for OTA operations.

## Version Management

OTASDK follows [Semantic Versioning](https://semver.org/).

- **MAJOR** version when you make incompatible API changes
- **MINOR** version when you add functionality in a backward compatible manner
- **PATCH** version when you make backward compatible bug fixes

### Current Version: 1.0.0

#### Version History
- **1.0.0** (2026-04-13): Initial release to CocoaPods

## License

OTASDK is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Author

chenshuangchao, 915893620@qq.com

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/phy-sz-app/OTASDK/issues) page.