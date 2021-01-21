# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Build
    # Factory calss
    class Factory < AttributeContainer
      # Configuration derived factories
      class Dsl < AttributeContainer::Dsl
        def trait(name, description = nil, &block)
          factory = Build::Factory.new(
            context: @delegate.context,
            parent: @delegate,
            key: @delegate.key.with(name),
            name: [@delegate.name, name].compact.join("_"),
            source_location: block.source_location,
            description: description || __default_trait_description(trait: name)
          )

          factory.dsl_config(&block)
          @delegate.context.add_factory(factory)
        end

        protected

        def __default_trait_description(trait:)
          trait.to_s.gsub("_", " ").chomp
        end
      end

      attr_reader :key, :context, :name, :source_location
      attr_accessor :init_with

      def initialize(context:, parent: nil, key:, name:, description: nil, source_location:, values: nil)
        super(parent: parent, description: description)

        raise "Parent factory must have same type" unless parent.nil? || parent.key.type == key.type

        @context = context
        @key = key
        @name = name.to_sym
        @source_location = source_location
        @values = values&.dup || {}
      end

      def create(context:)
        evaluator = AttributeEvaluator.new(context: context)

        collect_attributes_and_values(evaluator: evaluator)

        before_create(evaluator: evaluator)

        object = create_object(evaluator: evaluator)

        set_properties(object: object, evaluator: evaluator)

        after_create(evaluator: evaluator, object: object)

        object
      end

      def add_values(values)
        @values.merge!(values)
      end

      def setup(test_class:); end

      protected

      def collect_attributes_and_values(evaluator:)
        @parent&.collect_attributes_and_values(evaluator: evaluator)
        evaluator.add_attributes(@attributes.values)
        evaluator.add_values(@values)
      end

      def before_create(evaluator:)
        @parent&.before_create(evaluator: evaluator)
        evaluator.evaluate(&@before_create) unless @before_create.nil?
      end

      def after_create(evaluator:, object:)
        @parent&.after_create(evaluator: evaluator, object: object)
        evaluator.evaluate(object, &@after_create) unless @after_create.nil?
      end

      def nearest_init_with
        @init_with || @parent&.nearest_init_with
      end

      def create_object(evaluator:)
        init_with = nearest_init_with

        if init_with.nil?
          call_initializer(evaluator: evaluator)
        else
          evaluator.evaluate(&init_with)
        end
      end

      def set_properties(object:, evaluator:)
        evaluator.attributes.each_value do |attribute|
          object.send(:"#{attribute.name}=", evaluator.value(name: attribute.name)) if attribute.type == :property
        end

        evaluator.values.each do |name, value| # rubocop:disable Style/HashEachMethods
          object.send(:"#{name}=", value) unless evaluator.attribute?(name: name)
        end
      end

      def call_initializer(evaluator:)
        parameters = []
        options = {}

        @key.type.instance_method(:initialize).parameters.each do |type, name|
          case type
          when :req
            parameters << evaluator.value(name: name)
          when :opt
            parameters << evaluator.value(name: name) if evaluator.attribute?(name: name)
          when :keyreq
            options[name] = evaluator.value(name: name)
          when :key
            options[name] = evaluator.value(name: name) if evaluator.attribute?(name: name)
          end
        end

        @key.type.new(*parameters, **options)
      end
    end
  end
end
