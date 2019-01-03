# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in evil-seed.gemspec
gemspec

platform :mri do
  gem 'pg', '>= 0.20'
  gem 'mysql2'
  gem 'sqlite3'
  gem 'pry-byebug'
end

platform :jruby do
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'pry-debugger-jruby'
end
