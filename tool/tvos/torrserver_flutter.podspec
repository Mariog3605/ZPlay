Pod::Spec.new do |s|
  s.name = 'torrserver_flutter'
  s.version = '0.0.7'
  s.summary = 'Embedded TorrServer for tvOS'
  s.homepage = 'https://github.com/tzero86/torrserver_flutter'
  s.license = { :file => '../LICENSE' }
  s.author = 'TorrServer Flutter Contributors'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :tvos, '15.0'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.frameworks = 'SystemConfiguration', 'Foundation', 'Security'
  s.vendored_frameworks = 'TorrServerKit.xcframework'
end
