# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'evil_seed/version'

Gem::Specification.new do |spec|
  spec.name          = 'evil-seed'
  spec.version       = EvilSeed::VERSION
  spec.authors       = ['Andrey Novikov', 'Vladimir Dementyev']
  spec.email         = ['envek@envek.name', 'palkan@evl.ms']

  spec.summary       = 'Create partial and anonymized production database dumps for use in development'
  spec.description   = <<-DESCRIPTION
    This gem allows you to easily dump and transform subset of your ActiveRecord models and their relations.
  DESCRIPTION
  spec.homepage      = 'https://github.com/palkan/evil-seed'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0'

  spec.add_dependency 'activerecord', '>= 5.0'

  spec.add_development_dependency 'rake',     '~> 12.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'pg',       '>= 0.20'
  spec.add_development_dependency 'mysql2'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'appraisal'
end
