# frozen_string_literal: true
require 'tempfile'

module EvilSeed
  #  - Runs all transformation objects for every tuple
  #  - Serializes transformed values back to basic types and writes it to dump
  class RecordDumper
    MAX_TUPLES_PER_INSERT_STMT = 1_000

    attr_reader :model_class, :configuration, :relation_dumper

    delegate :loaded_map, to: :relation_dumper

    def initialize(model_class, configuration, relation_dumper)
      @model_class     = model_class
      @configuration   = configuration
      @relation_dumper = relation_dumper
      @output          = Tempfile.new(["evil_seed_#{model_class.table_name}_", '.sql'])
      @header_written  = false
      @tuples_written  = 0
    end

    # Extracts, transforms, and dumps record +attributes+
    # @return [Boolean] Was this record dumped or not
    def call(attributes)
      return false unless loaded!(attributes)
      write!(transform_and_anonymize(attributes))
      true
    end

    # @return [IO] Dump for this model's table
    def result
      finalize!
      @output
    end

    private

    def loaded!(attributes)
      id = model_class.primary_key && attributes[model_class.primary_key] || attributes
      return false if loaded_map[model_class.table_name].include?(id)
      loaded_map[model_class.table_name] << id
    end

    def transform_and_anonymize(attributes)
      customizers = configuration.customizers[model_class.to_s]
      return attributes unless customizers
      customizers.inject(attributes) do |attrs, customizer|
        customizer.call(attrs)
      end
    end

    def insertable_column_names
      model_class.columns_hash.reject do |k,v|
        v.respond_to?(:virtual?) ? v.virtual? : false
      end.keys
    end

    def insert_statement
      connection = model_class.connection
      table_name = connection.quote_table_name(model_class.table_name)
      columns    = insertable_column_names.map { |c| connection.quote_column_name(c) }.join(', ')
      "INSERT INTO #{table_name} (#{columns}) VALUES\n"
    end

    def write!(attributes)
      # Remove non-insertable columns from attributes
      attributes = attributes.slice(*insertable_column_names)

      @output.write("-- #{relation_dumper.association_path}\n") && @header_written = true unless @header_written
      @output.write(@tuples_written.zero? ? insert_statement : ",\n")
      @output.write("  (#{prepare(attributes).join(', ')})")
      @tuples_written += 1
      @output.write(";\n") && @tuples_written = 0 if @tuples_written == MAX_TUPLES_PER_INSERT_STMT
    end

    def finalize!
      return unless @header_written && @tuples_written > 0
      @output.write(";\n\n")
      @tuples_written = 0
    end

    def prepare(attributes)
      attributes.map do |key, value|
        type = model_class.attribute_types[key]
        model_class.connection.quote(type.serialize(value))
      end
    end
  end
end
