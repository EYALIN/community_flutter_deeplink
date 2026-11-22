#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint community_flutter_deeplink.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'community_flutter_deeplink'
  s.version          = '1.2.1'
  s.summary          = 'Deep links for Flutter: launch link, link stream, launch and probe other apps.'
  s.description      = <<-DESC
The URL the app was opened with, a stream of links received while it runs, launching (openURL) and probing (canOpenURL) other apps.
                       DESC
  s.homepage         = 'https://github.com/EYALIN/community_flutter_deeplink'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Community Flutter Plugins' => 'community-flutter-plugins@users.noreply.github.com' }
  s.source           = { :path => '.' }
  s.source_files = 'community_flutter_deeplink/Sources/community_flutter_deeplink/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'community_flutter_deeplink_privacy' => ['community_flutter_deeplink/Sources/community_flutter_deeplink/PrivacyInfo.xcprivacy']}
end
