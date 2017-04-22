# frozen_string_literal: true

require_relative 'configuration/root'
require_relative 'anonymizer'

module EvilSeed
  # This module holds configuration for creating dump: which models and their constraints
  module Configuration
    def self.roots
      @roots ||= []
    end

    def self.root(model, *constraints)
      new_root = Root.new(model, *constraints)
      yield new_root if block_given?
      roots << new_root
    end

    def self.customize(model_class, &block)
      raise(ArgumentError, "You must provide block for #{__method__} method") unless block
      customizers[model_class.to_s] << block
    end

    def self.anonymize(model_class, &block)
      raise(ArgumentError, "You must provide block for #{__method__} method") unless block
      customizers[model_class.to_s] << Anonymizer.new(model_class, &block)
    end

    def self.customizers
      @customizers ||= Hash.new { |h, k| h[k] = [] }
    end
  end
end
