#
# Be sure to run `pod lib lint EaseCallUIKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'EaseCallUIKit'
  s.version          = '4.18.0'
  s.summary          = 'A short description of EaseCallUIKit.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/easemob/easemob-callkit-iOS'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zjc19891106' => '984065974@qq.com' }
  s.source           = { :git => 'https://github.com/easemob/easemob-callkit-iOS.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '15.0'

  s.source_files = 'Sources/EaseCallUIKit/Classes/**/*.{h,m,swift}'

  s.resource_bundles = {
    'EaseCallUIKit' => ['Sources/EaseCallUIKit/Classes/Resources/*.bundle']
  }
  
  s.static_framework = true
  
  s.swift_version = '5.0'
  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'Foundation', 'Combine', 'AudioToolbox', 'AVFoundation','AVKit', 'CoreMedia', 'CoreVideo', 'CoreGraphics'
  
  s.dependency 'HyphenateChat'
  s.dependency 'AgoraRtcEngine_iOS/RtcBasic', '4.1.0'
end
