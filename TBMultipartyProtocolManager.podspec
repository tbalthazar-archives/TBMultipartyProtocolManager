Pod::Spec.new do |s|
  s.name = 'TBMultipartyProtocolManager'
  s.version = '0.0.1'
  s.platform = :ios, '7.0'
  #s.license = { :type => 'BSD', :file => 'copying.txt' }
  #s.summary = ''
  s.homepage = 'https://github.com/tbalthazar/TBMultipartyProtocolManager'
  s.author = { 'Thomas Balthazar' => 'xxx' }
  s.source = { :git => 'https://github.com/tbalthazar/TBMultipartyProtocolManager.git' } #, :tag => '3.6.2' }

  s.description = ''
  s.requires_arc = true

  s.public_header_files = 'TBMultipartyProtocolManager/TBMultipartyProtocolManager.h'
  #s.public_header_files = 'TBMultipartyProtocolManager/**/*.h'
  #s.private_header_files = 'TBMultipartyProtocolManager/dependencies/include/**/*.h'
  s.header_dir = 'openssl'
  s.header_mappings_dir = 'TBMultipartyProtocolManager/dependencies/include'
  
  s.source_files = "TBMultipartyProtocolManager/**/*.{h,m,c}"
  #s.source_files = "TBMultipartyProtocolManager/**/*.{m,c}"
  
  s.vendored_library = 'TBMultipartyProtocolManager/dependencies/lib/*.a'
  
  #s.library	  = 'crypto', 'ssl'
end