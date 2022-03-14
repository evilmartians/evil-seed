# frozen_string_literal: true

module EvilSeed
  # This class constructs customizer callable with simple DSL:
  #
  #     config.anonymize("User")
  #       name  { Faker::Name.name }
  #       email { Faker::Internet.email }
  #     end
  #
  # Resulting object can be called with record attributes and will return modified copy.
  #
  #     attrs = { name: 'Luke', email: 'luke@skywalker.com' }
  #     a.call(attrs)
  #     attrs # => { name: 'John', email: 'bob@example.com' }
  #
  class Anonymizer
    # @param model_name [String] A string containing class name of your ActiveRecord model
    def initialize(model_name, &block)
      @model_class = model_name.constantize
      @changers = {}
      instance_eval(&block)
    end

    # @param attributes [Hash{String=>void}] Record attributes.
    # @return           [Hash{String=>void}] Modified deep copy of +attributes+
    def call(attributes)
      attributes.deep_dup.tap do |attrs|
        @changers.each do |attribute, changer|
          attrs[attribute] = changer.call(attrs[attribute])
        end
      end
    end

    def respond_to_missing?(attribute_name)
      @model_class.column_names.include?(attribute_name.to_s) || super
    end

    private

    def method_missing(attribute_name, &block)
      return super unless @model_class.column_names.include?(attribute_name.to_s)
      @changers[attribute_name.to_s] = block
    end
  end
end
