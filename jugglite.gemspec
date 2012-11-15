# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jugglite/version'

Gem::Specification.new do |gem|
  gem.name          = "jugglite"
  gem.version       = Jugglite::VERSION
  gem.authors       = ["andruby"]
  gem.email         = ["andrew@bedesign.be"]
  gem.description   = %q{Lightweight SSE server}
  gem.summary       = %q{Server Sent Events server written in rack on top of thin inspired by Juggernaut for real time push}
  gem.homepage      = "http://github.com/andruby/jugglite"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency('thin')
  gem.add_dependency('em-hiredis')
  gem.add_development_dependency('redis')
  gem.add_development_dependency('rspec')
end
