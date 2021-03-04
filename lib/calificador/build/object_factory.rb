# typed: strict
# frozen_string_literal: true

module Calificador
  module Build
    # Factory for objects
    class ObjectFactory < BasicFactory
      # Configuration derived factories
      class Dsl < BasicFactory::Dsl
        sig { params(factory: ObjectFactory).void }
        def initialize(factory:)
          super(factory: factory)

          @property_type = ::T.let(nil, ::T.nilable(::Symbol))
        end

        sig { params(block: ::T.nilable(::T.proc.void)).void }
        def transient(&block)
          ::Kernel.raise ArgumentError, "Transient requires a block" if block.nil?

          old_property_type = @property_type
          @property_type = :transient

          begin
            instance_exec(&::T.unsafe(block))
          ensure
            @property_type = old_property_type
          end
        end

        protected

        sig do
          override.params(
            trait: ::Symbol,
            description: ::T.nilable(::String),
            source_location: ::T.nilable(Util::SourceLocation)
          ).returns(BasicFactory)
        end
        def __create_factory(trait:, description:, source_location:)
          ObjectFactory.new(
            context: __factory.context,
            parent: __factory,
            key: __factory.key.with(trait),
            name: [__factory.name, trait].compact.join("_").to_sym,
            source_location: source_location,
            description: description || __default_trait_description(trait: trait)
          )
        end

        sig { override.params(name: ::Symbol).returns(::Symbol) }
        def __default_property_type(name:)
          __factory.parent&.attribute(name: name)&.type || @property_type || :property
        end
      end

      sig do
        params(
          context: Context::BasicContext,
          key: Key,
          name: Symbol,
          description: T.nilable(String),
          parent: T.nilable(BasicFactory),
          source_location: T.nilable(Util::SourceLocation)
        ).void
      end
      def initialize(context:, key:, name:, description: nil, parent: nil, source_location: nil)
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

      sig { params(evaluator: AttributeEvaluator).returns(BasicObject) }
      def instantiate_object(evaluator:)
        arguments = []
        keywords = {}

        initializer = @key.type.instance_method(:initialize)

        parameters = if defined?(::T)
          T::Private::Methods.signature_for_method(initializer)&.method&.parameters || initializer.parameters
        else
          initializer.parameters
        end

        parameters.each do |type, name|
          case type
          when :req
            arguments << evaluator.value(name: name)
          when :opt
            arguments << evaluator.value(name: name) if evaluator.attribute?(name: name)
          when :keyreq
            keywords[name] = evaluator.value(name: name)
          when :key
            keywords[name] = evaluator.value(name: name) if evaluator.attribute?(name: name)
          end
        end

        @key.type.new(*arguments, **keywords)
      end
    end
  end
end
