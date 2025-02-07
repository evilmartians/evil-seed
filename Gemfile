# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in evil-seed.gemspec
gemspec

activerecord_version = ENV.fetch("ACTIVERECORD_VERSION", "~> 8.0")
case activerecord_version.upcase
when "HEAD"
  git "https://github.com/rails/rails.git" do
    gem "activerecord"
    gem "rails"
  end
else
  activerecord_version = "~> #{activerecord_version}.0" if activerecord_version.match?(/^\d+\.\d+$/)
  gem "activerecord", activerecord_version
  if Gem::Version.new("7.2") > Gem::Version.new(activerecord_version.scan(/\d+\.\d+/).first)
    gem "sqlite3", "~> 1.4"
    gem "concurrent-ruby", "< 1.3.5"
  end
end

gem "debug"
