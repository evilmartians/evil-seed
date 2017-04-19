# frozen_string_literal: true

require_relative 'configuration/root'

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
  end
end
