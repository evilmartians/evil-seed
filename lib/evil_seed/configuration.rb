# frozen_string_literal: true

require_relative 'configuration/root'
require_relative 'record_dumper'
require_relative 'anonymizer'

module EvilSeed
  # This module holds configuration for creating dump: which models and their constraints
  class Configuration
    attr_accessor :record_dumper_class, :verbose, :verbose_sql, :unscoped, :dont_nullify

    def initialize
      @record_dumper_class = RecordDumper
      @verbose = false
      @verbose_sql = false
      @unscoped = false
      @dont_nullify = false
      @ignored_columns = Hash.new { |h, k| h[k] = [] }
    end

    def roots
      @roots ||= []
    end

    def root(model, *constraints)
      new_root = Root.new(model, dont_nullify, *constraints)
      yield new_root if block_given?
      roots << new_root
    end

    def customize(model_class, &block)
      raise(ArgumentError, "You must provide block for #{__method__} method") unless block
      customizers[model_class.to_s] << ->(attrs) { attrs.tap(&block) } # Ensure that we're returning attrs from it
    end

    def anonymize(model_class, &block)
      raise(ArgumentError, "You must provide block for #{__method__} method") unless block
      customizers[model_class.to_s] << Anonymizer.new(model_class, &block)
    end

    def ignore_columns(model_class, *columns)
      @ignored_columns[model_class.to_s] += columns.map(&:to_s)
    end

    # Customizer objects for every model
    # @return [Hash{String => Array<#call>}]
    def customizers
      @customizers ||= Hash.new { |h, k| h[k] = [] }
    end

    def ignored_columns_for(model_class)
      @ignored_columns[model_class]
    end
  end
end
