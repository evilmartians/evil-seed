# frozen_string_literal: true

module EvilSeed
  class Configuration
    # Configuration for dumping some root model and its associations
    class Root
      attr_reader :model, :constraints, :limit, :order
      attr_reader :total_limit, :association_limits, :deep_limit, :dont_nullify
      attr_reader :exclusions, :inclusions

      # @param model       [String]       Name of the model class to dump
      # @param constraints [String, Hash] Everything you can feed into +where+ to limit number of records
      def initialize(model, dont_nullify, *constraints)
        @model = model
        @constraints = constraints
        @exclusions = []
        @inclusions = {}
        @association_limits = {}
        @deep_limit = nil
        @dont_nullify = dont_nullify
      end

      # Exclude some of associations from the dump
      # @param association_patterns Array<String, Regex> Patterns to exclude associated models from dump
      def exclude(*association_patterns)
        association_patterns.each do |pattern|
          case pattern
          when String, Regexp
            @exclusions << pattern
          else
            path_prefix = model.constantize.model_name.singular
            @exclusions += compile_patterns(pattern, prefix: path_prefix).map { |p| Regexp.new(/\A#{p}\z/) }
          end
        end
      end

      # Include some excluded associations back to the dump
      # @param association_patterns Array<String, Regex> Patterns to exclude associated models from dump
      def include(*association_patterns, &block)
        association_patterns.each do |pattern|
          case pattern
          when String, Regexp
            @inclusions[pattern] = block
          else
            path_prefix = model.constantize.model_name.singular
            compile_patterns(pattern, prefix: path_prefix).map do |p|
              @inclusions[Regexp.new(/\A#{p}\z/)] = block
            end
          end
        end
      end

      def exclude_has_relations
        @excluded_has_relations = :exclude_has_relations
      end

      def exclude_optional_belongs_to
        @excluded_optional_belongs_to = :exclude_optional_belongs_to
      end

      def limit(limit = nil)
        return @limit if limit.nil?

        @limit = limit
      end

      def order(order = nil)
        return @order if order.nil?

        @order = order
      end

      # Limit number of records in all (if pattern is not provided) or given  associations to include into dump
      # @param limit               [Integer]       Maximum number of records in associations to include into dump
      # @param association_pattern Array<String, Regex, Hash> Pattern to limit number of records for certain associated models
      def limit_associations_size(limit, *association_patterns)
        return @total_limit = limit if association_patterns.empty?

        association_patterns.each do |pattern|
          case pattern
          when String, Regexp
            @association_limits[pattern] = limit
          else
            path_prefix = model.constantize.model_name.singular
            compile_patterns(pattern, prefix: path_prefix, partial: false).map do |p|
              @association_limits[Regexp.new(/\A#{p}\z/)] = limit
            end
          end
        end
      end

      # Limit deepenes of associations to include into dump
      # @param limit               [Integer]       Maximum level to recursively dive into associations
      def limit_deep(limit)
        @deep_limit = limit
      end

      def do_not_nullify(nullify_flag)
        @dont_nullify = nullify_flag
      end

      def excluded?(association_path)
        exclusions.find { |exclusion| association_path.match(exclusion) } #.match(association_path) }
      end

      def included?(association_path)
        inclusions.find { |inclusion, _block| association_path.match(inclusion) }
      end

      def excluded_has_relations?
        @excluded_has_relations
      end

      def excluded_optional_belongs_to?
        @excluded_optional_belongs_to
      end

      private

      def compile_patterns(pattern, prefix: "", partial: true)
        wrap = -> (p) { partial ? "(?:\\.#{p})?" : "\\.#{p}" }
        case pattern
        when String, Symbol
          ["#{prefix}#{wrap.(pattern.to_s)}"]
        when Regexp
          ["#{prefix}#{wrap.("(?:#{pattern.source})")}"]
        when Array
          pattern.map { |p| compile_patterns(p, prefix: prefix, partial: partial) }.flatten
        when Hash
          pattern.map do |k, v|
            next nil unless v
            subpatterns = compile_patterns(v, partial: partial)
            next "#{prefix}#{wrap.(k)}" if subpatterns.empty?

            subpatterns.map do |p|
              "#{prefix}#{wrap.("#{k}#{p}")}"
            end
          end.compact.flatten
        when false, nil
          nil
        when true
          [prefix]
        else
          raise ArgumentError, "Unknown pattern type: #{pattern.class} for #{pattern.inspect}"
        end
      end
    end
  end
end
