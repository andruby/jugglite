# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'juglite/version'

Gem::Specification.new do |gem|
  gem.name          = "juglite"
  gem.version       = Juglite::VERSION
  gem.authors       = ["andruby"]
  gem.email         = ["andrew@bedesign.be"]
  gem.description   = %q{Lightweight SSE server}
  gem.summary       = %q{Replacement for Juggernaut that uses Server Sent Events for real time push}
  gem.homepage      = "http://github.com/andruby/juglite"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency('thin')
  gem.add_dependency('em-hiredis')
end
