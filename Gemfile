# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in evil-seed.gemspec
gemspec

activerecord_version = ENV.fetch("ACTIVERECORD_VERSION", "~> 7.0")
case activerecord_version.upcase
when "HEAD"
  git "https://github.com/rails/rails.git" do
    gem "activerecord"
    gem "rails"
  end
else
  activerecord_version = "~> #{activerecord_version}.0" if activerecord_version.match?(/^\d+\.\d+$/)
  gem "activerecord", activerecord_version
end
