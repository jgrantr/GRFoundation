#
# Be sure to run `pod lib lint GRFoundation.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GRFoundation'
  s.version          = '0.4.4'
  s.summary          = 'Utility extensions to the Foundation and UIKit frameworks'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This collects a number of categories that flesh-out the Foundation and UIKit frameworks with some much-needed
functionality. Includes a number of image manipulation and creation routines, as well as some helpers for
extracting useful data about a iOS device.
                       DESC

  s.homepage         = 'https://github.com/jgrantr/GRFoundation'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Grant Robinson' => 'grant@zayda.com' }
  s.source           = { :git => 'https://github.com/jgrantr/GRFoundation.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'GRFoundation/Classes/**/*'
  
  # s.resource_bundles = {
  #   'GRFoundation' => ['GRFoundation/Assets/*.png']
  # }

  s.public_header_files = 'GRFoundation/Classes/**/GR*.h', 'GRFoundation/Classes/**/UI*.h', 'GRFoundation/Classes/**/NS*.h'
  s.frameworks = 'UIKit', 'Foundation'
  s.dependency 'CocoaLumberjack', '~> 2.4'
end
