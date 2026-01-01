# ios/RNNetworkQuality.podspec
#
# Pod specification for CocoaPods integration.
# Declares native dependencies and iOS configuration.

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
  
    # Swift setup
    s.swift_version    = "5.3"
    s.requires_arc     = true
  
    # Source files
    s.source_files     = "**/*.{swift,h,m}"
    s.exclude_files    = "**/*.podspec"
  
    # React Native dependencies
    s.dependency "React-Core"
    s.dependency "React-cxxreact"
    s.dependency "React-jsi"
  
    # iOS frameworks
    s.frameworks       = "Foundation", "Network", "NetworkExtension"
  
    # Compiler flags for TurboModule
    s.compiler_flags   = "-DRNM_TURBOMODULE=1"
  
    # Header search paths
    s.header_search_paths = "#{s.name}/Sources"
  end