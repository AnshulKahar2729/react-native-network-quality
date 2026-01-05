Pod::Spec.new do |s|
  s.name             = "RNNetworkQuality"
  s.version          = "1.0.0"
  s.summary          = "React Native network quality measurement library"

  s.description      = <<-DESC
    Cross-platform React Native library for estimating real-world network quality
    using native measurements and lightweight heuristics.
  DESC

  s.homepage         = "https://github.com/AnshulKahar2729/react-native-network-quality"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = { "Anshul Kahar" => "anshulkahar2211@gmail.com" }

  s.platform         = :ios, "13.0"
  s.source           = { :path => "." }

  # Swift
  s.swift_version    = "5.3"
  s.requires_arc     = true
  s.static_framework = true
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES"
  }

  # Source files
  s.source_files     = "ios/**/*.{h,m,mm,swift}"

  s.dependency "React-Core"

  # System frameworks
  s.frameworks = [
    "Foundation",
    "Network",
    "NetworkExtension"
  ]

  # TurboModule flag
  s.compiler_flags = "-DRNM_TURBOMODULE=1"
end
