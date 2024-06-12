source 'https://github.com/tapkey/TapkeyCocoaPods'
source 'https://cdn.cocoapods.org/'

platform :ios, '13.0'
inhibit_all_warnings!

target 'witte-mobile-sample' do
  use_frameworks!
  pod 'AppAuth'
  pod 'TapkeyMobileLib', '2.39.3.0'
  pod 'witte-mobile-library', '3.1.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
