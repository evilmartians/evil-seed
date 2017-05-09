# frozen_string_literal: true

require 'active_record'

require_relative 'evil_seed/version'
require_relative 'evil_seed/configuration'
require_relative 'evil_seed/dumper'

# Generate anonymized dumps for your ActiveRecord models
module EvilSeed
  DEFAULT_CONFIGURATION = EvilSeed::Configuration.new

  def self.configure
    yield DEFAULT_CONFIGURATION
  end

  # Make the actual dump
  # @param filepath_or_io [String, IO] Path to result dumpfile or IO to write results into
  def self.dump(filepath_or_io)
    io = if filepath_or_io.respond_to?(:write) # IO
           filepath_or_io
         else
           File.open(filepath_or_io, mode: 'w')
         end
    EvilSeed::Dumper.new(DEFAULT_CONFIGURATION).call(io)
  end
end
