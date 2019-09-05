#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'remote_player'
  s.version          = '0.0.1'
  s.summary          = 'Background remote audio player for iOS and Android'
  s.description      = <<-DESC
A new Flutter project.
                       DESC
  s.homepage         = 'http://ebulan.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'felagund18' => 'felagund180@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  
  s.swift_version = '4.0'
  s.ios.deployment_target = '8.0'
end
