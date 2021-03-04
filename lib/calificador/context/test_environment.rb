# typed: strict
# frozen_string_literal: true

require "singleton"

module Calificador
  module Context
    # Environment to run test method
    class TestEnvironment < BasicContext
      # Placeholder for default values in method calls
      class DefaultValue
        include Singleton

        sig { returns(String) }
        def to_s
          "<default>"
        end

        alias_method :inspect, :to_s
      end

      DEFAULT_VALUE = T.let(DefaultValue.instance, DefaultValue)

      class Proxy < Util::OvertProxyObject
        extend ::Forwardable

        sig { params(environment: TestEnvironment).void }
        def initialize(environment:)
          super()

          @environment = environment
          @test_instance = ::T.let(environment.test_instance, TestType)
        end

        sig { params(arguments: BasicObject, body: ::T.nilable(::Proc)).returns(BasicObject) }
        def assert(*arguments, &body)
          if arguments.empty?
            proxy = self
            assertion = -> { ::T.unsafe(proxy).instance_exec(&body) } if body
            @environment.assert(&assertion)
          else
            ::T.unsafe(@test_instance).assert(*arguments, &body)
          end
        end

        ruby2_keywords :assert

        sig { params(arguments: BasicObject, body: ::T.nilable(::Proc)).returns(BasicObject) }
        def refute(*arguments, &body)
          if arguments.empty?
            proxy = self
            assertion = -> { ::T.unsafe(proxy).instance_exec(&body) } if body
            @environment.refute(&assertion)
          else
            ::T.unsafe(@test_instance).refute(*arguments, &body)
          end
        end

        ruby2_keywords :refute

        def_delegator :@environment, :subject
        def_delegator :@environment, :create
        def_delegator :@environment, :properties
        def_delegator :@environment, :arguments

        sig { returns(DefaultValue) }
        def _
          Context::TestEnvironment::DEFAULT_VALUE
        end

        sig { params(arguments: ArgumentArray, keywords: KeywordHash, block: T.nilable(Proc)).returns(BasicObject) }
        def call(*arguments, **keywords, &block)
          T.unsafe(@environment).call_operation(arguments: arguments, keywords: keywords, block: block)
        end

        ruby2_keywords :call

        sig { returns(BasicObject) }
        def result
          @environment.result
        end

        protected

        sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
        def __respond_to_missing?(name:, include_all:)
          if @environment.operation_name ||
             !@environment.lookup_named_factory(name: name).nil? ||
             @test_instance.respond_to?(name)
            true
          else
            false
          end
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
          if name == @environment.operation_name
            @environment.call_operation(arguments: arguments, keywords: keywords, block: block)
          else
            factory = @environment.lookup_named_factory(name: name)

            if factory
              @environment.create_object(key: factory.key)
            elsif @test_instance.respond_to?(name)
              ::T.unsafe(@test_instance).__send__(name, *arguments, **keywords, &block)
            else
              super
            end
          end
        end

        ruby2_keywords :__method_missing

        ::T::Sig::WithoutRuntime.sig { params(name: Symbol).void }
        def singleton_method_added(name) # rubocop:disable Lint/MissingSuper
          ::Kernel.raise "Adding methods (#{name}) inside test methods is not supported"
        end
      end

      sig { returns(TestType) }
      attr_reader :test_instance

      sig { returns(Proxy) }
      attr_reader :proxy

      sig { params(parent: TestMethod, test_instance: TestType, overrides: T::Array[Override::BasicOverride]).void }
      def initialize(parent:, test_instance:, overrides: [])
        super(
          parent: parent,
          subject_key: parent.subject_key,
          description: parent.method_name.to_s,
          overrides: overrides
        )

        @test_instance = test_instance
        @subject = T.let(MISSING, T.nilable(BasicObject))
        @result = T.let(MISSING, T.nilable(BasicObject))
        @created_objects = T.let({}, T::Hash[Key, BasicObject])
        @current_assertor = T.let(nil, T.nilable(Assertor))
        @proxy = T.let(Proxy.new(environment: self), Proxy)
      end

      sig { params(value: BasicObject).returns(BasicObject) }
      def subject(value = MISSING)
        if value.equal?(MISSING)
          if @subject.equal?(MISSING)
            @result = MISSING
            @subject = create_subject(environment: self)
          end
        else
          @result = MISSING
          @subject = value
        end

        @subject
      end

      sig { params(arguments: ArgumentArray, keywords: KeywordHash, block: T.nilable(Proc)).returns(BasicObject) }
      def call_operation(arguments:, keywords:, block: nil)
        effective_arguments, effective_keywords = collect_arguments(arguments: arguments, keywords: keywords)

        operation_name = self.operation_name || raise("No parent context defines an operation")

        @result = case [effective_arguments.empty?, effective_keywords.empty?]
          in [false, false]
            T.unsafe(subject).__send__(operation_name, *effective_arguments, **effective_keywords, &block)
          in [false, true]
            T.unsafe(subject).__send__(operation_name, *effective_arguments, &block)
          in [true, false]
            T.unsafe(subject).__send__(operation_name, **effective_keywords, &block)
          in [true, true]
            T.unsafe(subject).__send__(operation_name, &block)
        end
      end

      ruby2_keywords :call_operation

      sig { returns(BasicObject) }
      def result
        raise StandardError, "Method under test was not called yet, so there is no result" if @result == MISSING

        @result
      end

      sig { params(type: Module, trait: T.nilable(Symbol)).returns(BasicObject) }
      def create(type, trait = Key::NO_TRAIT)
        create_object(key: Key[type, trait])
      end

      sig { params(block: T.nilable(T.proc.void)).returns(Assertor) }
      def assert(&block)
        @current_assertor&.__check_triggered
        @current_assertor = Assertor.new(handler: @test_instance, block: block)
      end

      sig { params(block: T.nilable(T.proc.void)).returns(Assertor) }
      def refute(&block)
        @current_assertor&.__check_triggered
        @current_assertor = Assertor.new(handler: @test_instance, negated: true, block: block)
      end

      sig { params(block: T.proc.void).returns(Override::ArgumentOverride) }
      def arguments(&block)
        raise "Cannot override properties after method under test has been called" unless @result == EMPTY

        super.then do |override|
          override.apply(context: self)
        end
      end

      sig do
        params(
          type: T.nilable(Module),
          trait: T.nilable(Symbol),
          block: T.proc.void
        ).returns(Override::PropertyOverride)
      end
      def properties(type = nil, trait = Key::DEFAULT_TRAIT, &block)
        raise "Cannot override properties after objects have been created" unless @created_objects.empty?

        super.then do |override|
          override.apply(context: self)
        end
      end

      sig { params(key: Key).returns(BasicObject) }
      def create_object(key:)
        @created_objects.fetch(key) do
          factory = lookup_factory(key: key)

          @created_objects[key] = if factory
            factory.create(environment: self)
          else
            raise(KeyError, "No factory found for #{key}") if key.trait?

            key_type = key.type

            if key_type <= Singleton
              T.unsafe(key_type).instance
            elsif key_type.is_a?(Class)
              method = key_type.method(:new)

              if method.required_arguments?
                raise KeyError, "Class #{key} has no default constructor, cannot create without factory"
              end

              key_type.send(:new)
            elsif key_type.is_a?(Module)
              key_type
            else
              raise(KeyError, "Cannot create object for #{key} without factory")
            end
          end
        end
      end

      sig { params(error: T::Boolean).void }
      def done(error:)
        @current_assertor&.__check_triggered unless error
        @current_assertor = nil
      end

      sig { void }
      def run_test
        test_method = T.cast(parent, TestMethod)

        if test_method.expected_to_fail
          passed = begin
            T.unsafe(@proxy).instance_exec(&test_method.body)
            true
          rescue ::Minitest::Assertion => e
            @test_instance.pass(e.message)
            false
          end

          @test_instance.flunk("Expected test to fail") if passed
        else
          T.unsafe(@proxy).instance_exec(&test_method.body)
        end

        done(error: false)
      rescue StandardError
        done(error: true)
        raise
      end

      sig { returns(String) }
      def to_s
        "#{self.class.name}(#{@test_instance.name})"
      end

      protected

      sig { params(arguments: ArgumentArray, keywords: KeywordHash).returns([ArgumentArray, KeywordHash]) }
      def collect_arguments(arguments:, keywords:)
        default_arguments = operation_arguments

        arguments = arguments.each_with_index.map do |argument, index|
          if argument.equal?(DEFAULT_VALUE)
            unless default_arguments.key?(index)
              raise "Please provide a default value for positional argument ##{index} of '#{operation_name}'"
            end

            config = default_arguments[index]
            argument = T.unsafe(proxy).instance_exec(&config)
          end

          argument
        end

        keywords = keywords.map do |name, value|
          if value.equal?(DEFAULT_VALUE)
            unless default_arguments.key?(name)
              raise "Please provide a default value for keyword argument '#{name}' of '#{operation_name}'"
            end

            config = default_arguments[name]
            value = T.unsafe(proxy).instance_exec(&config)
          end

          [name, value]
        end.to_h

        [arguments, keywords]
      end
    end
  end
end
