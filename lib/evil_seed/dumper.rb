# frozen_string_literal: true

module EvilSeed
  # This module performs actual dump generation
  class Dumper
    attr_reader :configuration

    # @param configuration [Configuration]
    def initialize(configuration)
      @configuration = configuration
      @loaded_map = {}
    end

    # Generate dump and write it into +io+
    # @param output [IO] Stream to write SQL dump into
    def call(output)
      @output = output
      configuration.roots.each do |root|
        model_class = root.model.constantize
        model_class.where(*root.constraints).find_each do |record|
          dump_record!(record, root, model_class.model_name.singular)
        end
      end
    ensure
      output.close
    end

    private

    def dump_relation!(relation, root, association_path)
      relation.each do |record|
        dump_record!(record, root, association_path)
      end
    end

    def dump_record!(record, root, association_path)
      loaded!(record) || return
      # Dumping belongs_to records first to satisfy possible foreign key checks on restoring
      belongs_to_associations(record, root, association_path).each do |reflection_name, _reflection|
        dump_reflection!(record, reflection_name, root, association_path)
      end
      @output.write(insert_statement(record))
      other_associations(record, root, association_path).each do |reflection_name, _reflection|
        dump_reflection!(record, reflection_name, root, association_path)
      end
    end

    def dump_reflection!(record, reflection_name, root, association_path)
      relation_or_record = record.send(reflection_name)
      return unless relation_or_record
      case relation_or_record
      when ActiveRecord::Base then dump_record!(relation_or_record, root, "#{association_path}.#{reflection_name}")
      else dump_relation!(relation_or_record, root, "#{association_path}.#{reflection_name}")
      end
    end

    def loaded!(record)
      model_class = record.class.base_class
      @loaded_map[model_class] ||= {}
      id = record.attributes[model_class.primary_key]
      return false if @loaded_map[model_class].key?(id)
      @loaded_map[model_class][id] = true
    end

    def belongs_to_associations(record, root, association_path)
      record._reflections.select do |reflection_name, reflection|
        next false unless reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection)
        root.exclusions.none? { |e| e.match("#{association_path}.#{reflection_name}") }
      end
    end

    def other_associations(record, root, association_path)
      record._reflections.select do |reflection_name, reflection|
        next false if reflection.is_a?(ActiveRecord::Reflection::BelongsToReflection)
        next false if reflection.parent_reflection
        root.exclusions.none? { |e| e.match("#{association_path}.#{reflection_name}") }
      end
    end

    def to_values(record)
      record.attributes.map do |key, value|
        record.class.connection.quote(record.class.attribute_types[key].serialize(value))
      end
    end

    def insert_statement(record)
      conn = record.class.connection
      table_name = conn.quote_table_name(record.class.table_name)
      columns = record.class.attribute_names.map { |c| conn.quote_column_name(c) }.join(', ')
      "INSERT INTO #{table_name} (#{columns}) VALUES (#{to_values(record).join(', ')});\n" # TODO: Do this with AR
    end
  end
end
