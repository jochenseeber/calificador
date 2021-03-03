# frozen_string_literal: true

require "minitest"
require "forwardable"

using Calificador::Util::CoreExtensions

module Calificador
  # Mixin for unit tests
  module TestMixin
    extend Forwardable

    Key = Calificador::Key

    class << self
      def included(includer)
        includer.extend(ClassMethods)
      end

      def prepended(prepender)
        prepender.extend(ClassMethods)
      end
    end

    def singleton_method_added(method)
      raise "Adding singleton methods (#{method}) to tests is not supported here" if __current_test_environment?

      super
    end

    def_delegator :__current_test_environment, :subject
    def_delegator :__current_test_environment, :create

    def __run_test(context:)
      stack_marker = "calificador_test_#{SecureRandom.uuid.gsub("-", "_")}"

      environment = Context::TestEnvironment.new(parent: context, test_instance: self)
      __register_current_environment(stack_marker: stack_marker, environment: environment)

      begin
        instance_eval(<<~METHOD, stack_marker, 1)
          environment.run_test
        METHOD
      ensure
        __unregister_current_environment(stack_marker: stack_marker)
      end
    end

    protected

    def __register_current_environment(stack_marker:, environment:)
      @__calificador_current_test_environment = environment
      Calificador::Test.__register_current_environment(stack_marker: stack_marker, environment: environment)
    end

    def __unregister_current_environment(stack_marker:)
      if !instance_variable_defined?(:@__calificador_current_test_environment) || @__calificador_current_test_environment.nil?
        raise StandardError, "No current test run registered"
      end

      Calificador::Test.__unregister_current_environment(stack_marker: stack_marker)
      @__calificador_current_test_environment = nil
    end

    def __current_test_environment
      if !instance_variable_defined?(:@__calificador_current_test_environment) || @__calificador_current_test_environment.nil?
        raise StandardError, "No current test run registered"
      end

      @__calificador_current_test_environment
    end

    def __current_test_environment?
      instance_variable_defined?(:@__calificador_current_test_environment) || !@__calificador_current_test_environment
    end

    # Class methods for unit tests
    module ClassMethods
      extend Forwardable

      def run_all_tests(reporter: MiniTest::CompositeReporter.new)
        runnable_methods.each do |method|
          run_one_method(self, method, reporter)
        end
      end

      def examines(subject_class, *description_or_trait_or_init)
        if instance_variable_defined?(:@__calificador_root_context) && @__calificador_root_context
          raise <<~MESSAGE.gsub("\n", " ")
            Cannot specify 'examines' after a test context has been defined. The 'examines' statement should be the first statement in your test class
          MESSAGE
        end

        arguments = Context::BasicContext.extract_arguments(
          subject_key: Key[subject_class],
          values: description_or_trait_or_init,
          names: %i[description trait init]
        )

        arguments.description ||= __default_instance_description(subject_key: arguments.subject_key)

        @__calificador_root_context = Context::TestRoot.new(
          test_class: self,
          subject_key: arguments.subject_key,
          description: arguments.description
        )
      end

      def_delegators :__calificador_current_context, :factory, :mock
      def_delegators :__calificador_current_context, :type, :examine, :operation, :with, :without, :where
      def_delegators :__calificador_current_context, :must, :must_fail
      def_delegators :__calificador_current_context, :args, :props

      def body(&block)
        class_eval(&block)
      end

      def __default_type_description(subject_key:)
        subject_key.type.name_without_common_parents(base: self)
      end

      def __default_instance_description(subject_key:)
        description = StringIO.new

        description << subject_key.type.name_without_common_parents(base: self)
        description << "(" << subject_key.trait.to_s.gsub("_", " ") << ")" if subject_key.trait?

        description.string
      end

      def __default_factory_name(subject_key:)
        description = StringIO.new

        description << subject_key.type.base_name.snake_case
        description << "_" << subject_key.trait.to_s if subject_key.trait?

        description.string
      end

      def __root_context
        if !instance_variable_defined?(:@__calificador_root_context) || @__calificador_root_context.nil?
          subject_key = __calificador_guess_subject_key

          @__calificador_root_context = Context::TestRoot.new(
            test_class: self,
            subject_key: subject_key,
            description: __default_instance_description(subject_key: subject_key)
          )
        end

        @__calificador_root_context
      end

      def __register_current_environment(stack_marker:, environment:)
        __calificador_test_lock.synchronize do
          if __calificador_test_environments.key?(stack_marker)
            raise KeyError,
                  "Test run #{stack_marker} already registered"
          end

          __calificador_test_environments[stack_marker] = environment
        end
      end

      def __unregister_current_environment(stack_marker:)
        __calificador_test_lock.synchronize do
          if __calificador_test_environments.delete(stack_marker).nil?
            raise KeyError, "Could not unregister test #{stack_marker}"
          end
        end
      end

      def __current_test_environment
        __calificador_test_lock.synchronize do
          location = ::Kernel.caller_locations.find do |l|
            %r{\Acalificador_test_[a-zA-Z0-9_]+\z} =~ l.path
          end

          raise StandardError, "Could not find current test run in call stack" unless location

          __calificador_test_environments.fetch(location.path) do
            raise KeyError, "No test run registered for #{location.path}"
          end
        end
      end

      def __calificador_configure(context:, block:)
        __calificador_push_context(context)

        begin
          class_exec(&block)
        ensure
          __calificador_pop_context
        end
      end

      def method_added(method)
        if !method.start_with?("test_: ") && __calificador_contexts.size > 1
          raise "Adding methods (#{method}) to tests is not supported here"
        end

        super
      end

      protected

      def __calificador_contexts
        if !instance_variable_defined?(:@__calificador_contexts) || @__calificador_contexts.nil?
          @__calificador_contexts = [__root_context]
        end

        @__calificador_contexts
      end

      def __calificador_push_context(context)
        __calificador_contexts.push(context)
        context
      end

      def __calificador_pop_context
        raise "Cannot remove root context" unless __calificador_contexts.size > 1

        __calificador_contexts.pop
      end

      def __calificador_current_context
        __calificador_contexts.last
      end

      def __calificador_test_environments
        @__calificador_test_environments = {} unless instance_variable_defined?(:@__calificador_test_environments)

        @__calificador_test_environments
      end

      def __calificador_test_lock
        @__calificador_test_lock = Mutex.new unless instance_variable_defined?(:@__calificador_test_lock)

        @__calificador_test_lock
      end

      def __calificador_guess_subject_key
        type_name = name&.gsub(%r{(?<=\w)Test\z}, "")

        unless type_name
          raise StandardError, <<~MESSAGE.gsub("\n", " ")
            Cannot guess test subject class from test class name '#{name}'. Please use 'examines' to specify the test subject.
          MESSAGE
        end

        unless Kernel.const_defined?(type_name)
          raise StandardError, <<~MESSAGE.gsub("\n", " ")
            Guessed test subject type (#{type_name}) does not exist. Please use 'examines' to specify the test subject.
          MESSAGE
        end

        subject_type = Kernel.const_get(type_name)

        if subject_type <= Singleton || subject_type <= BasicObject || subject_type.is_a?(Module)
          Key[subject_type]
        else
          raise StandardError, <<~MESSAGE.gsub("\n", " ")
            Guessed test subject type (#{subject_type}) is not a Class, a Module or a Singleton. Please use 'examines'
            to specify the test subject.
          MESSAGE
        end
      end
    end
  end
end
