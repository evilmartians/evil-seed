# frozen_string_literal: true

require 'set'
require_relative 'root_dumper'

module EvilSeed
  # This class concatenates dumps from all root into one single file
  class Dumper
    attr_reader :configuration, :loaded_map

    # @param configuration [Configuration]
    # @param output [IO] Stream to write SQL dump into
    def initialize(configuration, output)
      @configuration = configuration
      @loaded_map = Hash.new { |h, k| h[k] = Set.new } # stores primary keys of already dumped records for every table
      @output = output
    end

    # Generate dump and write it into provided +io+
    def call
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
