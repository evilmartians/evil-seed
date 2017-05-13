# frozen_string_literal: true

require_relative 'relation_dumper'

module EvilSeed
  # This module collects dumps generation for root and all it's dependencies
  class RootDumper
    attr_reader :root, :dumper, :model_class, :total_limit, :association_limits

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
      relation = model_class.all
      relation = relation.where(*root.constraints) if root.constraints.any? # without arguments returns not a relation
      RelationDumper.new(relation, self, association_path).call
    end

    # @return [Boolean] +true+ if limits are NOT reached and +false+ otherwise
    def check_limits!(association_path)
      check_total_limit! && check_association_limits!(association_path)
    end

    private

    def check_total_limit!
      return true  if total_limit.nil?
      return false if total_limit.zero?
      @total_limit -= 1
      true
    end

    def check_association_limits!(association_path)
      return true if association_limits.none?
      applied_limits = association_limits.select { |path, _limit| path.match(association_path) }
      return false if applied_limits.any? { |_path, limit| limit.zero? }
      applied_limits.each do |path, _limit|
        association_limits[path] -= 1
      end
      true
    end
  end
end
