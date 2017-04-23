# frozen_string_literal: true

module EvilSeed
  # This class performs actual dump generation for single relation and all its not yet loaded dependencies
  #
  #  - Fetches all tuples for root (it does not instantiate AR records but it casts values to Ruby types)
  #  - Extracts foreign key values for all belongs_to associations
  #  - Dumps belongs_to associations(recursion!)
  #  - Dumps all tuples for root, writes them in file
  #  - Dumps all other associations (recursion!)
  #  - Returns all results to caller
  #
  class RelationDumper
    MAX_IDENTIFIERS_IN_IN_STMT = 1_000
    MAX_TUPLES_PER_INSERT_STMT = 1_000

    attr_reader :relation, :root_dumper, :model_class, :association_path, :search_key, :identifiers, :nullify_columns,
                :belongs_to_reflections, :has_many_reflections, :foreign_keys, :loaded_ids, :to_load_map, :output,
                :inverse_reflection, :table_names, :options

    delegate :loaded_map, :table_outputs, :root, :configuration, :total_limit, to: :root_dumper

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
      @output                 = Tempfile.new(["evil_seed_#{model_class.table_name}_", '.sql'])
      @nullify_columns        = []
      @table_names            = {}
      @belongs_to_reflections = setup_belongs_to_reflections
      @has_many_reflections   = setup_has_many_reflections
      @options                = options
      @header_written         = false
      @tuples_written         = 0
    end

    # Generate dump and write it into +io+
    # @return [Array<IO>] List of dump IOs for separate tables in order of dependencies (belongs_to are first)
    def call
      dump!

      belongs_to_dumps = belongs_to_reflections.map do |reflection|
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
      has_many_dumps = has_many_reflections.map do |reflection|
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

      output.write(";\n\n") if @header_written

      [belongs_to_dumps, output, has_many_dumps].flatten.compact
    end

    private

    def dump!
      if identifiers.present?
        # Don't use AR::Base#find_each as we will get error on Oracle if we will have more than 1000 ids in IN statement
        identifiers.in_groups_of(MAX_IDENTIFIERS_IN_IN_STMT).each do |ids|
          fetch_attributes(relation.where(search_key => ids.compact)).each do |attributes|
            dump_attributes!(attributes)
          end
        end
      else
        relation.in_batches do |relation|
          fetch_attributes(relation).each do |attributes|
            dump_attributes!(attributes)
          end
        end
      end
    end

    # Selects attributes as a hash with typecasted values for all rows from +relation+
    # @param relation [ActiveRecord::Relation]
    # @return [Array<Hash{String => String, Integer, Float, Boolean, nil}>]
    def fetch_attributes(relation)
      relation.pluck(*model_class.attribute_names).map do |row|
        Hash[model_class.attribute_names.zip(row)]
      end
    end

    def dump_attributes!(attributes)
      return unless loaded!(attributes)
      foreign_keys.each do |reflection_name, fk_column|
        foreign_key = attributes[fk_column]
        next if foreign_key.nil? || loaded_map[table_names[reflection_name]].include?(foreign_key)
        to_load_map[reflection_name] << foreign_key
      end
      loaded_ids << attributes[model_class.primary_key]
      nullify_columns.each do |nullify_column|
        attributes[nullify_column] = nil
      end

      write!(transform_and_anonymize(attributes))
    end

    def loaded!(attributes)
      return false unless check_limits!
      id = model_class.primary_key && attributes[model_class.primary_key] || attributes
      return false if loaded_map[model_class.table_name].include?(id)
      loaded_map[model_class.table_name] << id
    end

    def transform_and_anonymize(attributes)
      customizers = configuration.customizers[model_class.to_s]
      return attributes unless customizers
      attributes.tap do |attributes|
        customizers.each { |customizer| customizer.call(attributes) }
      end
    end

    def insert_statement
      connection = model_class.connection
      table_name = connection.quote_table_name(model_class.table_name)
      columns    = model_class.attribute_names.map { |c| connection.quote_column_name(c) }.join(', ')
      "INSERT INTO #{table_name} (#{columns}) VALUES\n"
    end

    def write!(attributes)
      output.write("-- #{association_path}\n") && @header_written = true unless @header_written
      output.write(@tuples_written.zero? ? insert_statement : ",\n")
      output.write("  (#{prepare(attributes).join(', ')})")
      @tuples_written += 1
      output.write(";\n") && @tuples_written = 0 if @tuples_written == MAX_TUPLES_PER_INSERT_STMT
    end

    def prepare(attributes)
      attributes.map do |key, value|
        model_class.connection.quote(serialize(attribute_types[key], value))
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
          nullify_columns << reflection.foreign_key
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

    # Handles ActiveRecord API differences between AR 4.2 and 5.0
    def attribute_types
      return @attribute_types if defined?(@attribute_types)
      @attribute_types = if model_class.respond_to?(:attribute_types)
                           model_class.attribute_types
                         else
                           model_class.column_types
                         end
    end

    # Handles ActiveRecord API differences between AR 4.2 and 5.0
    # Casts a value from the ruby type to a type that the database knows how to understand.
    def serialize(type, value)
      if type.respond_to?(:serialize)
        type.serialize(value)
      else
        type.type_cast_for_database(value)
      end
    end
  end
end
