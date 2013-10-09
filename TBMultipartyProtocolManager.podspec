Pod::Spec.new do |s|
  s.name = 'TBMultipartyProtocolManager'
  s.version = '0.0.1'
  s.platform = :ios, '7.0'
  s.homepage = 'https://github.com/tbalthazar/TBMultipartyProtocolManager'
  s.author = { 'Thomas Balthazar' => 'xxx' }
  s.source = { :git => 'https://github.com/tbalthazar/TBMultipartyProtocolManager.git' }
  s.description = ''
  s.requires_arc = true

  s.public_header_files = 'TBMultipartyProtocolManager/TBMultipartyProtocolManager.h'  
  s.source_files = "TBMultipartyProtocolManager/**/*.{h,m,c}"
  s.header_mappings_dir = "TBMultipartyProtocolManager/dependencies/include"
  s.vendored_library = 'TBMultipartyProtocolManager/dependencies/lib/*.a'
end