# frozen_string_literal: true

require_relative 'relation_dumper'

module EvilSeed
  # This module performs dump generation for root and all it's dependencies
  class RootDumper
    attr_reader :root, :dumper, :model_class

    delegate :loaded_map, :configuration, to: :dumper

    def initialize(root, dumper)
      @root   = root
      @dumper = dumper
      @to_load_map = {}
      @total_limit = root.total_limit
      @association_limits = root.association_limits.dup

      @model_class = root.model.constantize
    end

    # Generate dump and write it into +io+
    # @param output [IO] Stream to write SQL dump into
    def call
      association_path = model_class.model_name.singular
      RelationDumper.new(model_class.where(*root.constraints), self, association_path).call
    end
  end
end
