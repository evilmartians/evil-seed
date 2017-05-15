# frozen_string_literal: true

require "bundler/setup"
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

ADAPTERS = %w[postgresql sqlite mysql].freeze

namespace :test do
  ADAPTERS.each do |adapter|
    task adapter => ["#{adapter}:env", :test]

    namespace adapter do
      task(:env) { ENV['DB'] = adapter }
    end
  end
end

task default: :test
