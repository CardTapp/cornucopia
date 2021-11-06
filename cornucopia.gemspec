# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Maintain your gem's version:
require "cornucopia/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "cornucopia"
  spec.version     = Cornucopia::VERSION
  spec.authors = ["RealNobody"]
  spec.email   = ["RealNobody1@cox.net"]
  spec.summary     = "A collection of tools to simplify testing tasks."
  spec.description = "A collection of tools I created to simplify and make it easier to see what is happening."
  spec.homepage    = "https://github.com/RealNobody/cornucopia"
  spec.license = "MIT"

  # spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  spec.files = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "> 4.0", "< 7.0"

  spec.add_development_dependency "rails"
  # spec.add_development_dependency "mysql2"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "cucumber"
  spec.add_development_dependency "cucumber-rails"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "site_prism"
  spec.add_development_dependency "selenium-webdriver"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "launchy"
  spec.add_development_dependency "rack"
end