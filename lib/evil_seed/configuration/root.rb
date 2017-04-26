# frozen_string_literal: true

module EvilSeed
  class Configuration
    # Configuration for dumping some root model and its associations
    class Root
      attr_reader :model, :constraints
      attr_reader :total_limit, :association_limits
      attr_reader :exclusions

      # @param model       [String]       Name of the model class to dump
      # @param constraints [String, Hash] Everything you can feed into +where+ to limit number of records
      def initialize(model, *constraints)
        @model = model
        @constraints = constraints
        @exclusions = []
        @association_limits = {}
      end

      # Exclude some of associations from the dump
      # @param association_patterns Array<String, Regex> Patterns to exclude associated models from dump
      def exclude(*association_patterns)
        @exclusions += association_patterns
      end

      # Limit number of records in all (if pattern is not provided) or given  associations to include into dump
      # @param limit               [Integer]       Maximum number of records in associations to include into dump
      # @param association_pattern [String, Regex] Pattern to limit number of records for certain associated models
      def limit_associations_size(limit, association_pattern = nil)
        if association_pattern
          @association_limits[association_pattern] = limit
        else
          @total_limit = limit
        end
      end

      def excluded?(association_path)
        exclusions.any? { |exclusion| exclusion.match(association_path) }
      end
    end
  end
end
