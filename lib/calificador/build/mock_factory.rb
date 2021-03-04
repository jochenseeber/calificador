# typed: strict
# frozen_string_literal: true

module Calificador
  module Build
    # Factory for mock objects
    class MockFactory < BasicFactory
      include Util::EscapeHatch

      # Configuration derived factories
      class Dsl < BasicFactory::Dsl
        sig { params(block: ::T.proc.void).void }
        def expect(&block)
          ::T.cast(__factory, MockFactory).expect = block
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
          MockFactory.new(
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
          :transient
        end
      end

      class ExpectProxy < Util::OvertProxyObject
        sig { params(mock: ::T.untyped, evaluator: Build::AttributeEvaluator).void }
        def initialize(mock:, evaluator:)
          super()

          @mock = mock
          @mock_proxy = ::T.let(MockProxy.new(mock: @mock), MockProxy)
          @evaluator = evaluator
          @environment = ::T.let(@evaluator.environment, Context::TestEnvironment)
          @test_instance = ::T.let(@environment.test_instance, ::Minitest::Test)
        end

        sig { returns(::BasicObject) }
        def mock
          @mock_proxy
        end

        protected

        sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
        def __respond_to_missing?(name:, include_all:)
          @evaluator.attribute?(name: name) ||
            !@environment.lookup_named_factory(name: name).nil? ||
            @test_instance.respond_to?(name, false)
        end

        sig do
          params(
            name: ::Symbol,
            arguments: ArgumentArray,
            keywords: KeywordHash,
            block: ::T.nilable(::Proc)
          ).returns(::BasicObject)
        end
        def __method_missing(name:, arguments:, keywords:, block: nil)
          if @evaluator.attribute?(name: name)
            @evaluator.value(name: name)
          else
            factory = @environment.lookup_named_factory(name: name)

            if factory
              @environment.create_object(key: factory.key)
            else
              T.unsafe(@test_instance).send(name, *arguments, &block)
            end
          end
        end

        ruby2_keywords :__method_missing
      end

      class MockProxy < Util::OvertProxyObject
        sig { params(mock: ::T.untyped).void }
        def initialize(mock:)
          super()

          @mock = mock
        end

        sig { params(name: ::Symbol, arguments: BasicObject, block: ::T.nilable(::Proc)).returns(MockCall) }
        def call(name, *arguments, &block)
          MockCall.new(mock: @mock, name: name, arguments: arguments, block: block)
        end

        ruby2_keywords :call

        protected

        sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
        def __respond_to_missing?(name:, include_all:)
          METHOD_PATTERN =~ name.to_s ? true : super
        end

        sig do
          params(
            name: ::Symbol,
            arguments: ArgumentArray,
            keywords: KeywordHash,
            block: ::T.nilable(::Proc)
          ).returns(::BasicObject)
        end
        def __method_missing(name:, arguments:, keywords:, block: nil)
          if METHOD_PATTERN =~ name.to_s
            MockCall.new(mock: @mock, name: name, arguments: arguments, keywords: keywords, block: block)
          else
            super
          end
        end

        ruby2_keywords :__method_missing
      end

      class MockCall
        sig { returns(Symbol) }
        attr_reader :name

        sig { returns(ArgumentArray) }
        attr_reader :arguments

        sig { returns(KeywordHash) }
        attr_reader :keywords

        sig { returns(::T.nilable(::Proc)) }
        attr_reader :block

        sig do
          params(
            mock: ::T.untyped,
            name: Symbol,
            arguments: ArgumentArray,
            keywords: KeywordHash,
            block: ::T.nilable(::Proc)
          ).void
        end
        def initialize(mock:, name:, arguments: [], keywords: {}, block: nil)
          @mock = mock
          @name = T.let(name, Symbol)
          @arguments = T.let(arguments, ArgumentArray)
          @keywords = T.let(keywords, KeywordHash)
          @block = T.let(block, ::T.nilable(::Proc))
        end

        sig { params(other: BasicObject).returns(T.self_type) }
        def >>(other)
          arguments = @arguments.dup
          arguments << @keywords unless @keywords.empty?
          @mock.expect(@name, other, arguments)
          self
        end
      end

      sig { returns(T.nilable(T.proc.void)) }
      attr_accessor :expect

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

      sig { params(attribute: Attribute).void }
      def add_attribute(attribute)
        raise ArgumentError, "Attribute must be transient" unless attribute.type == :transient

        super
      end

      sig { params(object: BasicObject, evaluator: AttributeEvaluator).void }
      def set_properties(object:, evaluator:)
        ExpectProxy.new(mock: T.unsafe(object), evaluator: evaluator).instance_exec(&T.unsafe(@expect)) if @expect
      end

      protected

      sig { params(evaluator: AttributeEvaluator).returns(BasicObject) }
      def instantiate_object(evaluator:)
        mock = ::Minitest::Mock.new

        key_type = @key.type

        # Use unchecked version so Sorbet does not call any methods on the mock
        mock_singleton_class = unchecked_singleton_class_of(mock)

        mock_singleton_class.define_method(:is_a?) do |type|
          key_type <= type
        end

        mock
      end
    end
  end
end
