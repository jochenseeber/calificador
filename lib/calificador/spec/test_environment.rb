# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    # Environment to run test method
    class TestEnvironment
      def initialize(test:, context:)
        @test = test
        @context = context
        @subject = MISSING
        @call_arguments = []
        @call_options = {}
        @call_block = nil
        @call_result = MISSING
        @created_objects = {}
        @current_assertor = nil
      end

      def subject(value = MISSING)
        if value.equal?(MISSING)
          if @subject.equal?(MISSING)
            @call_result = MISSING
            @subject = @context.create_subject(environment: self, subject_key: @context.subject_key)
          end
        else
          @call_result = MISSING
          @subject = value
        end

        @subject
      end

      def arguments(*arguments, **options, &block)
        @call_arguments = arguments.nil? ? [] : arguments
        @call_options = options.nil? ? {} : options
        @call_block = block
        @call_result = MISSING
        nil
      end

      def call(*arguments, **options, &block)
        options.empty? ? arguments(*arguments, &block) : arguments(*arguments, **options, &block)
        result
      end

      def result
        if @call_result == MISSING
          @call_result = @context.create_result(
            subject: subject,
            arguments: @call_arguments,
            options: @call_options,
            block: @call_block
          )
        end

        @call_result
      end

      def create(type, trait = nil)
        create_object(key: Key[type, trait])
      end

      def assert(&block)
        @current_assertor&.__check_triggered

        @current_assertor = Assertor.new(test: @test, block: block || __default_assert_block)
      end

      def refute(&block)
        @current_assertor&.__check_triggered

        @current_assertor = Assertor.new(test: @test, negated: true, block: block || __default_assert_block)
      end

      def respond_to_missing?(method, include_all)
        @context.lookup_named_factory(name: method) || super
      end

      def method_missing(method, *arguments, **options, &block)
        factory = @context.lookup_named_factory(name: method)

        if factory
          create_object(key: factory.key)
        else
          super
        end
      end

      def create_object(key:)
        @created_objects.fetch(key) do
          factory = @context.lookup_factory(key: key)

          object = if factory.nil?
            raise(KeyError, "No factory found for #{key}") if key.trait != Key::DEFAULT_TRAIT

            constructor = key.type.method(:new)
            constructor.invoke
          else
            factory.create(context: self)
          end

          @created_objects[key] = object
        end
      end

      def __done
        @current_assertor&.__check_triggered
      end

      protected

      def __default_assert_block
        lambda do
          result
        end
      end

      # def __pass(message = nil)
      #   @test.pass(message)
      # end

      # def __flunk(message = nil)
      #   @test.flunk(message)
      # end

      # def __assert(condition, message = nil)
      #   @test.assert(condition, message)
      # end

      # def __refute(condition, message = nil)
      #   @test.refute(condition, message)
      # end

      # def __exception_details(exception, message)
      #   @test.exception_details(exception, message)
      # end
    end
  end
end
