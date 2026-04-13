Pod::Spec.new do |s|
  s.name             = 'OTASDK'
  s.version          = '1.0.0'
  s.summary          = 'BLE OTA SDK for PHY devices'
  s.description      = <<-DESC
A Bluetooth Low Energy (BLE) Over-The-Air (OTA) firmware update SDK for PHY devices.
                       DESC
  s.homepage         = 'https://github.com/phy-sz-app/OTASDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'chenshuangchao' => '915893620@qq.com' }
  s.source           = { :git => 'https://github.com/phy-sz-app/OTASDK.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.source_files = 'OTASDK/OTASDK/**/*.{h,m}'
  s.public_header_files = 'OTASDK/OTASDK/**/*.h'
  s.frameworks = 'UIKit', 'CoreBluetooth'
  s.requires_arc = true
end