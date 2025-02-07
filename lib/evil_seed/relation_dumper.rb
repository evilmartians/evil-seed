# frozen_string_literal: true

require 'active_support/core_ext/array/grouping'

# As method ActiveRecord::Relation#in_batches is available only since ActiveRecord 5.0
# we will backport it only for us via refinements for ActiveRecord 4.2 compatibility.
unless ActiveRecord::Batches.instance_methods(false).include?(:in_batches)
  require_relative 'refinements/in_batches'
  using EvilSeed::Refinements::InBatches
end

module EvilSeed
  # This class performs actual dump generation for single relation and all its not yet loaded dependencies
  #
  #  - Fetches all tuples for root (it does not instantiate AR records but it casts values to Ruby types)
  #  - Extracts foreign key values for all belongs_to associations
  #  - Dumps belongs_to associations(recursion!)
  #  - Dumps all tuples for root, writes them in file
  #  - Dumps all other associations (recursion!)
  #  - Returns all results to caller in correct order
  #
  # TODO: This class obviously breaks SRP principle and thus should be split!
  class RelationDumper
    MAX_IDENTIFIERS_IN_IN_STMT = 1_000

    attr_reader :relation, :root_dumper, :model_class, :association_path, :search_key, :identifiers, :nullify_columns,
                :belongs_to_reflections, :has_many_reflections, :foreign_keys, :loaded_ids, :local_load_map,
                :records, :record_dumper, :inverse_reflection, :table_names, :options,
                :current_deep, :verbose, :custom_scope

    delegate :root, :configuration, :dont_nullify, :total_limit, :deep_limit, :loaded_map, :to_load_map, to: :root_dumper

    def initialize(relation, root_dumper, association_path, **options)
      puts("- #{association_path}") if root_dumper.configuration.verbose

      @relation               = relation
      @root_dumper            = root_dumper
      @verbose                = configuration.verbose
      @identifiers            = options[:identifiers]
      @local_load_map         = Hash.new { |h, k| h[k] = [] }
      @foreign_keys           = Hash.new { |h, k| h[k] = [] }
      @loaded_ids             = []
      @model_class            = relation.klass
      @search_key             = options[:search_key] || model_class.primary_key
      @association_path       = association_path
      @inverse_reflection     = options[:inverse_of]
      @records                = []
      @record_dumper          = configuration.record_dumper_class.new(model_class, configuration, self)
      @nullify_columns        = []
      @table_names            = {}
      @belongs_to_reflections = setup_belongs_to_reflections
      @has_many_reflections   = setup_has_many_reflections
      @options                = options
      @current_deep           = association_path.split('.').size
      @dont_nullify           = dont_nullify
      @custom_scope           = options[:custom_scope]
    end

    # Generate dump and write it into +io+
    # @return [Array<IO>] List of dump IOs for separate tables in order of dependencies (belongs_to are first)
    def call
      dump!
      if deep_limit and current_deep > deep_limit
        [dump_records!].flatten.compact
      else
        [
          dump_belongs_to_associations!,
          dump_records!,
          dump_has_many_associations!,
        ].flatten.compact
      end
    end

    private

    def dump!
      original_ignored_columns = model_class.ignored_columns
      model_class.ignored_columns += Array(configuration.ignored_columns_for(model_class.sti_name))
      model_class.send(:reload_schema_from_cache) if ActiveRecord.version < Gem::Version.new("6.1.0.rc1") # See https://github.com/rails/rails/pull/37581
      if custom_scope
        puts("  # #{search_key} (with scope)") if verbose
        attrs = fetch_attributes(relation)
        puts(" -- dumped #{attrs.size}") if verbose
        attrs.each do |attributes|
          next unless check_limits!
          dump_record!(attributes)
        end
      elsif identifiers.present?
        puts("  # #{search_key} => #{identifiers}") if verbose
        # Don't use AR::Base#find_each as we will get error on Oracle if we will have more than 1000 ids in IN statement
        identifiers.in_groups_of(MAX_IDENTIFIERS_IN_IN_STMT).each do |ids|
          attrs = fetch_attributes(relation.where(search_key => ids.compact))
          puts(" -- dumped #{attrs.size}") if verbose
          attrs.each do |attributes|
            next unless check_limits!
            dump_record!(attributes)
          end
        end
      else
        puts("  # #{relation.count}") if verbose
        relation.in_batches do |relation|
          attrs = fetch_attributes(relation)
          puts(" -- dumped #{attrs.size}") if verbose
          attrs.each do |attributes|
            next unless check_limits!
            dump_record!(attributes)
          end
        end
      end
    ensure
      model_class.ignored_columns = original_ignored_columns
    end

    def dump_record!(attributes)
      unless dont_nullify
        nullify_columns.each do |nullify_column|
          attributes[nullify_column] = nil
        end
      end
      records << attributes
      foreign_keys.each do |reflection_name, fk_column|
        foreign_key = attributes[fk_column]
        next if foreign_key.nil? || loaded_map[table_names[reflection_name]].include?(foreign_key) || to_load_map[table_names[reflection_name]].include?(foreign_key)
        local_load_map[reflection_name] << foreign_key
        to_load_map[table_names[reflection_name]] << foreign_key
      end
      loaded_ids << attributes[model_class.primary_key]
    end

    def dump_records!
      records.each do |attributes|
        record_dumper.call(attributes)
      end
      record_dumper.result
    end

    def dump_belongs_to_associations!
      belongs_to_reflections.map do |reflection|
        next if local_load_map[reflection.name].empty?
        RelationDumper.new(
          build_relation(reflection),
          root_dumper,
          "#{association_path}.#{reflection.name}",
          search_key:       reflection.association_primary_key,
          identifiers:      local_load_map[reflection.name],
          limitable:        false,
        ).call
      end
    end

    def dump_has_many_associations!
      has_many_reflections.map do |reflection, custom_scope|
        next if loaded_ids.empty? || total_limit.try(:zero?)
        RelationDumper.new(
          build_relation(reflection, custom_scope),
          root_dumper,
          "#{association_path}.#{reflection.name}",
          search_key:       reflection.foreign_key,
          identifiers:      loaded_ids - local_load_map[reflection.name],
          inverse_of:       reflection.inverse_of.try(:name),
          limitable:        true,
          custom_scope:     custom_scope,
        ).call
      end
    end

    # Selects attributes as a hash with typecasted values for all rows from +relation+
    # @param relation [ActiveRecord::Relation]
    # @return [Array<Hash{String => String, Integer, Float, Boolean, nil}>]
    def fetch_attributes(relation)
      relation.pluck(*model_class.column_names).map do |row|
        row = [row] if model_class.column_names.size == 1
        Hash[model_class.column_names.zip(row)]
      end
    end

    def check_limits!
      return true unless options[:limitable]
      root_dumper.check_limits!(association_path)
    end

    def build_relation(reflection, custom_scope = nil)
      if configuration.unscoped
        relation = reflection.klass.unscoped
      else
        relation = reflection.klass.all
      end
      relation = relation.instance_eval(&reflection.scope) if reflection.scope
      relation = relation.instance_eval(&custom_scope) if custom_scope
      relation = relation.where(reflection.type => model_class.to_s) if reflection.options[:as] # polymorphic
      relation
    end

    def setup_belongs_to_reflections
      model_class.reflect_on_all_associations(:belongs_to).reject do |reflection|
        next false if reflection.options[:polymorphic] # TODO: Add support for polymorphic belongs_to
        included = root.included?("#{association_path}.#{reflection.name}")
        excluded = reflection.options[:optional] && root.excluded_optional_belongs_to?
        excluded ||= root.excluded?("#{association_path}.#{reflection.name}")
        inverse = reflection.name == inverse_reflection
        puts " -- belongs_to #{reflection.name} #{"excluded by #{excluded}" if excluded} #{"re-included by #{included}" if included}" if verbose
        if excluded and not included
          if model_class.column_names.include?(reflection.foreign_key)
            puts(" -- excluded #{reflection.foreign_key}") if verbose
            nullify_columns << reflection.foreign_key
          end
        else
          foreign_keys[reflection.name] = reflection.foreign_key
          table_names[reflection.name]  = reflection.table_name
        end
        excluded and not included or inverse
      end
    end

    # This method returns only direct has_one and has_many reflections. For HABTM it returns intermediate has_many
    def setup_has_many_reflections
      puts(" -- reflections #{model_class._reflections.keys}") if verbose
      model_class._reflections.select do |_reflection_name, reflection|
        next false unless %i[has_one has_many].include?(reflection.macro)

        next false if model_class.primary_key.nil?

        next false if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)

        included = root.included?("#{association_path}.#{reflection.name}")
        excluded = :inverse if reflection.name == inverse_reflection
        excluded ||= root.excluded_has_relations?
        excluded ||= root.excluded?("#{association_path}.#{reflection.name}")
        puts " -- #{reflection.macro} #{reflection.name} #{"excluded by #{excluded}" if excluded} #{"re-included by #{included}" if included}" if verbose
        !(excluded and not included)
      end.map do |_reflection_name, reflection|
        [reflection, root.included?("#{association_path}.#{reflection.name}")&.last]
      end
    end
  end
end
