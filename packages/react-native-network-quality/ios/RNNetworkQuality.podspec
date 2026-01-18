require 'json'

package = JSON.parse(File.read(File.join(__dir__, '../package.json')))

Pod::Spec.new do |s|
  s.name             = "RNNetworkQuality"
  s.version          = package['version']
  s.summary          = "React Native network quality measurement library"

  s.description      = <<-DESC
    Cross-platform React Native library for estimating real-world network quality
    using native measurements and lightweight heuristics.
  DESC

  s.homepage         = "https://github.com/AnshulKahar2729/react-native-network-quality"
  s.license          = { :type => "MIT" }
  s.author           = { "Anshul Kahar" => "anshulkahar2211@gmail.com" }

  s.platforms        = { :ios => "13.4" }
  s.source           = { :git => "https://github.com/AnshulKahar2729/react-native-network-quality.git", :tag => "v#{s.version}" }

  # Swift
  s.swift_version    = "5.3"
  s.requires_arc     = true

  # Source files
  s.source_files     = "*.{h,m,mm,swift}"

  # Pod target configuration
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES"
  }

  # Dependencies
  s.dependency "React-Core"

  # System frameworks
  s.frameworks = [
    "Foundation",
    "Network",
    "NetworkExtension"
  ]
end
