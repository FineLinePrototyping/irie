# -*- encoding: utf-8 -*-  
$:.push File.expand_path("../lib", __FILE__)  
require "irie/version" 

Gem::Specification.new do |s|
  s.name        = 'irie'
  s.version     = ::Irie::VERSION
  s.authors     = ['Gary S. Weaver', 'Tommy Odom']
  s.email       = ['garysweaver@gmail.com']
  s.homepage    = 'https://github.com/FineLinePrototyping/irie'
  s.summary     = %q{Extend Inherited Resources.}
  s.description = %q{Extensions for Inherited Resources for request parameter-based filters, paging, ordering, includes, etc.}
  s.files = Dir['lib/**/*'] + ['Rakefile', 'README.md']
  s.license = 'MIT'
  s.add_dependency 'inherited_resources', '~> 1.4'
end
