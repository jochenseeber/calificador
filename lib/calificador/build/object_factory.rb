# frozen_string_literal: true

module Calificador
  module Build
    # Factory for objects
    class ObjectFactory < BasicFactory
      # Configuration derived factories
      class Dsl < BasicFactory::Dsl
        def initialize(factory:)
          super(factory: factory)

          @property_type = nil
        end

        def transient(&block)
          raise ArgumentError, "Transient requires a block" if block.nil?

          old_property_type = @property_type
          @property_type = :transient

          begin
            instance_exec(&block)
          ensure
            @property_type = old_property_type
          end
        end

        protected

        def __create_factory(trait:, description:, source_location:)
          ObjectFactory.new(
            context: __factory.context,
            parent: __factory,
            key: __factory.key.with(trait),
            name: [__factory.name, trait].compact.join("_"),
            source_location: source_location,
            description: description || __default_trait_description(trait: trait)
          )
        end

        def __default_property_type(name:)
          __factory.parent&.attribute(name: name)&.type || @property_type || :property
        end
      end

      def initialize(context:, parent: nil, key:, name:, description: nil, source_location:)
        unless parent.nil?
          raise "Parent factory must be a #{ObjectFactory}" unless parent.is_a?(ObjectFactory)
          raise "Parent factory must have same type" unless parent.key.type == key.type
        end

        super(
          context: context,
          parent: parent,
          key: key,
          name: name,
          description: description,
          source_location: source_location
        )
      end

      protected

      def instantiate_object(evaluator:)
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
