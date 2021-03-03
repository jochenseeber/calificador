# frozen_string_literal: true

module Calificador
  module Build
    # Factory for mock objects
    class MockFactory < BasicFactory
      # Configuration derived factories
      class Dsl < BasicFactory::Dsl
        def expect(&block)
          __factory.expect = block
        end

        protected

        def __create_factory(trait:, description:, source_location:)
          MockFactory.new(
            context: __factory.context,
            parent: __factory,
            key: __factory.key.with(trait),
            name: [__factory.name, trait].compact.join("_"),
            source_location: source_location,
            description: description || __default_trait_description(trait: trait)
          )
        end

        def __default_property_type(name:)
          :transient
        end
      end

      class ExpectProxy < Util::ProxyObject
        def initialize(mock:, evaluator:)
          super()

          @mock = mock
          @evaluator = evaluator
          @environment = @evaluator.environment
          @test_instance = @environment.test_instance
        end

        def mock
          MockProxy.new(mock: @mock)
        end

        protected

        def __respond_to_missing?(name:, include_all:)
          @evaluator.attribute?(name: name) ||
            !@environment.lookup_named_factory(name: name).nil? ||
            @test_instance.respond_to?(name, false)
        end

        def __method_missing(name:, arguments:, keywords:, block:)
          if @evaluator.attribute?(name: name)
            @evaluator.value(name: name)
          else
            factory = @environment.lookup_named_factory(name: name)

            if factory
              @environment.create_object(key: factory.key)
            else
              @test_instance.send(name, *arguments, **keywords, &block)
            end
          end
        end
      end

      class MockProxy < Util::ProxyObject
        def initialize(mock:)
          super()

          @mock = mock
        end

        protected

        def __respond_to_missing?(name:, include_all:)
          METHOD_PATTERN =~ name || super
        end

        def __method_missing(name:, arguments:, keywords:, block:)
          if METHOD_PATTERN =~ name
            MockCall.new(mock: @mock, name: name, arguments: arguments, keywords: keywords, block: block)
          else
            super
          end
        end
      end

      class MockCall
        attr_reader :name, :arguments, :keywords, :block

        def initialize(mock:, name:, arguments:, keywords:, block:)
          @mock = mock
          @name = name
          @arguments = arguments
          @keywords = keywords
          @block = block
        end

        def >>(other)
          @mock.expect(@name, other, combined_arguments)
        end

        protected

        def combined_arguments
          arguments = @arguments
          arguments += [@keywords] unless keywords.empty?
          arguments
        end
      end

      attr_accessor :expect

      def initialize(context:, parent: nil, key:, name:, description: nil, source_location:)
        unless parent.nil?
          raise "Parent factory must be a #{MockFactory}" unless parent.is_a?(MockFactory)
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

        @expect = nil
      end

      def add_attribute(attribute)
        raise ArgumentError, "Attribute must be transient" unless attribute.type == :transient

        super
      end

      def set_properties(object:, evaluator:)
        ExpectProxy.new(mock: object, evaluator: evaluator).instance_exec(&@expect) if @expect
      end

      protected

      def instantiate_object(evaluator:)
        ::Minitest::Mock.new
      end
    end
  end
end
