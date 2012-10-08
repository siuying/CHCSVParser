Pod::Spec.new do |s|
  s.name     = 'CHCSVParser'
  s.version  = '0.0.1'
  s.license  = 'MIT'
  s.summary  = 'A proper CSV parser for Objective-C.'
  s.homepage = 'https://github.com/davedelong/CHCSVParser'
  s.author   = { 'Dave DeLong' => 'http://davedelong.com/', 
    'Rainer Brockerhoff' => 'http://brockerhoff.net/' }
  s.source       = { :git => 'https://github.com/siuying/CHCSVParser.git', :commit => '00bc468' }
  s.source_files = 'CHCSVParser/**/*.{h,m}'
  s.requires_arc = true
end
