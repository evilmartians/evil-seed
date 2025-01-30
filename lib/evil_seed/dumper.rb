# frozen_string_literal: true

require 'set'
require_relative 'root_dumper'

module EvilSeed
  # This class initiates dump creation for every root model of configuration
  # and then concatenates dumps from all roots into one single IO.
  class Dumper
    attr_reader :configuration, :loaded_map, :to_load_map

    # @param configuration [Configuration]
    def initialize(configuration)
      @configuration = configuration
    end

    # Generate dump for this configuration and write it into provided +io+
    # @param output [IO] Stream to write SQL dump into
    def call(output)
      @loaded_map = Hash.new { |h, k| h[k] = Set.new } # stores primary keys of already dumped records for every table
      @to_load_map = Hash.new { |h, k| h[k] = Set.new } # stores primary keys of records we're going to dump to avoid cycles
      @output = output
      configuration.roots.each do |root|
        table_outputs = RootDumper.new(root, self).call
        table_outputs.each do |table_dump_io|
          table_dump_io.rewind
          IO.copy_stream(table_dump_io, @output)
        end
      end
    ensure
      @output.close
    end
  end
end
