# frozen_string_literal: true

require "singleton"

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    # Environment to run test method
    class TestEnvironment < BasicContext
      # Placeholder for default values in method calls
      class DefaultValue
        include Singleton

        def to_s
          "<default>"
        end

        alias_method :inspect, :to_s
      end

      DEFAULT_VALUE = DefaultValue.instance

      class Proxy < Util::ProxyObject
        extend ::Forwardable

        def initialize(environment:)
          super()

          @environment = environment
          @test_instance = environment.test_instance
        end

        def assert(*arguments, &body)
          if arguments.empty?
            @environment.assert do
              instance_exec(&body)
            end
          else
            @test_instance.assert(*arguments, &body)
          end
        end

        ruby2_keywords :assert

        def refute(*arguments, &body)
          if arguments.empty?
            @environment.refute do
              instance_exec(&body)
            end
          else
            @test_instance.refute(*arguments, &body)
          end
        end

        ruby2_keywords :refute

        def_delegator :@environment, :subject
        def_delegator :@environment, :create
        def_delegator :@environment, :properties
        def_delegator :@environment, :arguments

        def _
          Context::TestEnvironment::DEFAULT_VALUE
        end

        def call(*arguments, **keywords, &block)
          @environment.call_operation(*arguments, **keywords, &block)
        end

        def result
          @environment.result
        end

        protected

        def __respond_to_missing?(name:, include_all:)
          @environment.operation_name ||
            !@environment.lookup_named_factory(name: name).nil? ||
            @test_instance.respond_to?(name)
        end

        def __method_missing(name:, arguments:, keywords:, block:)
          if name == @environment.operation_name
            @environment.call_operation(*arguments, **keywords, &block)
          else
            factory = @environment.lookup_named_factory(name: name)

            if factory
              @environment.create_object(key: factory.key)
            elsif @test_instance.respond_to?(name)
              @test_instance.send(name, *arguments, **keywords, &block)
            else
              super
            end
          end
        end

        def singleton_method_added(name) # rubocop:disable Lint/MissingSuper
          ::Kernel.raise "Adding methods (#{name}) inside test methods is not supported"
        end
      end

      attr_reader :test_instance, :proxy

      def initialize(parent:, test_instance:, overrides: [])
        raise "Parent must be a #{TestMethod}" unless parent.is_a?(TestMethod)

        super(
          parent: parent,
          subject_key: parent.subject_key,
          description: parent.method_name.to_s,
          overrides: overrides
        )

        @test_instance = test_instance
        @subject = MISSING
        @result = MISSING
        @created_objects = {}
        @current_assertor = nil
        @proxy = Proxy.new(environment: self)
      end

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

      def call_operation(*arguments, **keywords, &block)
        effective_arguments, effective_options, effective_block = collect_arguments(
          arguments: arguments,
          keywords: keywords,
          block: block
        )

        @result = if effective_arguments.empty?
          if effective_options.empty?
            subject.__send__(operation_name, &block)
          else
            subject.__send__(operation_name, **effective_options, &effective_block)
          end
        else
          subject.__send__(operation_name, *effective_arguments, **effective_options, &effective_block)
        end
      end

      def result
        raise StandardError, "Method under test was not called yet, so there is no result" if @result == MISSING

        @result
      end

      def create(type, trait = Key::NO_TRAIT)
        create_object(key: Key[type, trait])
      end

      def assert(&block)
        @current_assertor&.__check_triggered
        @current_assertor = Assertor.new(handler: @test_instance, block: block)
      end

      def refute(&block)
        @current_assertor&.__check_triggered
        @current_assertor = Assertor.new(handler: @test_instance, negated: true, block: block)
      end

      def arguments(&block)
        raise "Cannot override properties after method under test has been called" unless @result == EMPTY

        super.then do |override|
          override.apply(context: self)
        end
      end

      def properties(type = nil, trait = Key::DEFAULT_TRAIT, &block)
        raise "Cannot override properties after objects have been created" unless @created_objects.empty?

        super.then do |override|
          override.apply(context: self)
        end
      end

      def create_object(key:)
        @created_objects.fetch(key) do
          factory = lookup_factory(key: key)

          @created_objects[key] = if factory
            factory.create(environment: self)
          else
            raise(KeyError, "No factory found for #{key}") if key.trait?

            if key.type.include?(Singleton)
              key.type.instance
            elsif key.type.is_a?(Class)
              method = key.type.method(:new)

              if method.required_arguments?
                raise KeyError, "Class #{key} has no default constructor, cannot create without factory"
              end

              key.type.send(:new)
            elsif key.type.is_a?(Module)
              key.type
            else
              raise(KeyError, "Cannot create object for #{key} without factory")
            end
          end
        end
      end

      def done(error:)
        @current_assertor&.__check_triggered unless error
        @current_assertor = nil
      end

      def run_test
        if parent.expected_to_fail
          passed = begin
            @proxy.instance_exec(&parent.body)
            true
          rescue ::Minitest::Assertion => e
            @test_instance.pass(e.message)
            false
          end

          @test_instance.flunk("Expected test to fail") if passed
        else
          @proxy.instance_exec(&parent.body)
        end

        done(error: false)
      rescue StandardError
        done(error: true)
        raise
      end

      def to_s
        "#{self.class.name}(#{@test_instance.name})"
      end

      protected

      def collect_arguments(arguments:, keywords:, block:)
        default_arguments = operation_arguments

        arguments = arguments.each_with_index.map do |argument, index|
          if argument.equal?(DEFAULT_VALUE)
            unless default_arguments.key?(index)
              raise "Please provide a default value for positional argument ##{index} of '#{operation_name}'"
            end

            config = default_arguments[index]
            argument = proxy.instance_exec(&config)
          end

          argument
        end

        keywords = keywords.map do |name, value|
          if value.equal?(DEFAULT_VALUE)
            unless default_arguments.key?(name)
              raise "Please provide a default value for keyword argument '#{name}' of '#{operation_name}'"
            end

            config = default_arguments[name]
            value = proxy.instance_exec(&config)
          end

          [name, value]
        end.to_h

        [arguments, keywords, block]
      end
    end
  end
end
