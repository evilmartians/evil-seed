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
                :belongs_to_reflections, :has_many_reflections, :foreign_keys, :loaded_ids, :to_load_map,
                :record_dumper, :inverse_reflection, :table_names, :options

    delegate :root, :configuration, :total_limit, :loaded_map, to: :root_dumper

    def initialize(relation, root_dumper, association_path, **options)
      @relation               = relation
      @root_dumper            = root_dumper
      @identifiers            = options[:identifiers]
      @to_load_map            = Hash.new { |h, k| h[k] = [] }
      @foreign_keys           = Hash.new { |h, k| h[k] = [] }
      @loaded_ids             = []
      @model_class            = relation.klass
      @search_key             = options[:search_key] || model_class.primary_key
      @association_path       = association_path
      @inverse_reflection     = options[:inverse_of]
      @record_dumper          = configuration.record_dumper_class.new(model_class, configuration, self)
      @nullify_columns        = []
      @table_names            = {}
      @belongs_to_reflections = setup_belongs_to_reflections
      @has_many_reflections   = setup_has_many_reflections
      @options                = options
    end

    # Generate dump and write it into +io+
    # @return [Array<IO>] List of dump IOs for separate tables in order of dependencies (belongs_to are first)
    def call
      dump!
      belongs_to_dumps = dump_belongs_to_associations!
      has_many_dumps   = dump_has_many_associations!
      [belongs_to_dumps, record_dumper.result, has_many_dumps].flatten.compact
    end

    private

    def dump!
      original_ignored_columns = model_class.ignored_columns
      model_class.ignored_columns += Array(configuration.ignored_columns_for(model_class.sti_name))
      model_class.send(:reload_schema_from_cache) if ActiveRecord.version < Gem::Version.new("6.1.0.rc1") # See https://github.com/rails/rails/pull/37581
      if identifiers.present?
        # Don't use AR::Base#find_each as we will get error on Oracle if we will have more than 1000 ids in IN statement
        identifiers.in_groups_of(MAX_IDENTIFIERS_IN_IN_STMT).each do |ids|
          fetch_attributes(relation.where(search_key => ids.compact)).each do |attributes|
            next unless check_limits!
            dump_record!(attributes)
          end
        end
      else
        relation.in_batches do |relation|
          fetch_attributes(relation).each do |attributes|
            next unless check_limits!
            dump_record!(attributes)
          end
        end
      end
    ensure
      model_class.ignored_columns = original_ignored_columns
    end

    def dump_record!(attributes)
      nullify_columns.each do |nullify_column|
        attributes[nullify_column] = nil
      end
      return unless record_dumper.call(attributes)
      foreign_keys.each do |reflection_name, fk_column|
        foreign_key = attributes[fk_column]
        next if foreign_key.nil? || loaded_map[table_names[reflection_name]].include?(foreign_key)
        to_load_map[reflection_name] << foreign_key
      end
      loaded_ids << attributes[model_class.primary_key]
    end

    def dump_belongs_to_associations!
      belongs_to_reflections.map do |reflection|
        next if to_load_map[reflection.name].empty?
        RelationDumper.new(
          build_relation(reflection),
          root_dumper,
          "#{association_path}.#{reflection.name}",
          search_key:       reflection.association_primary_key,
          identifiers:      to_load_map[reflection.name],
          limitable:        false,
        ).call
      end
    end

    def dump_has_many_associations!
      has_many_reflections.map do |reflection|
        next if loaded_ids.empty? || total_limit.try(:zero?)
        RelationDumper.new(
          build_relation(reflection),
          root_dumper,
          "#{association_path}.#{reflection.name}",
          search_key:       reflection.foreign_key,
          identifiers:      loaded_ids,
          inverse_of:       reflection.inverse_of.try(:name),
          limitable:        true,
        ).call
      end
    end

    # Selects attributes as a hash with typecasted values for all rows from +relation+
    # @param relation [ActiveRecord::Relation]
    # @return [Array<Hash{String => String, Integer, Float, Boolean, nil}>]
    def fetch_attributes(relation)
      relation.pluck(*model_class.column_names).map do |row|
        Hash[model_class.column_names.zip(row)]
      end
    end

    def check_limits!
      return true unless options[:limitable]
      root_dumper.check_limits!(association_path)
    end

    def build_relation(reflection)
      relation = reflection.klass.all
      relation = relation.instance_eval(&reflection.scope) if reflection.scope
      relation = relation.where(reflection.type => model_class.to_s) if reflection.options[:as] # polymorphic
      relation
    end

    def setup_belongs_to_reflections
      model_class.reflect_on_all_associations(:belongs_to).reject do |reflection|
        next false if reflection.options[:polymorphic] # TODO: Add support for polymorphic belongs_to
        excluded = root.excluded?("#{association_path}.#{reflection.name}") || reflection.name == inverse_reflection
        if excluded
          nullify_columns << reflection.foreign_key if model_class.column_names.include?(reflection.foreign_key)
        else
          foreign_keys[reflection.name] = reflection.foreign_key
          table_names[reflection.name]  = reflection.table_name
        end
        excluded
      end
    end

    # This method returns only direct has_one and has_many reflections. For HABTM it returns intermediate has_many
    def setup_has_many_reflections
      model_class._reflections.select do |_reflection_name, reflection|
        next false if model_class.primary_key.nil?
        next false if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)
        %i[has_one has_many].include?(reflection.macro) && !root.excluded?("#{association_path}.#{reflection.name}")
      end.map(&:second)
    end
  end
end
