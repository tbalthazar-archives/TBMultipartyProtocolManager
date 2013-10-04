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
  s.source_files = "TBMultipartyProtocolManager/**/*.{h,m,c}"
end