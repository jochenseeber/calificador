# typed: strict
# frozen_string_literal: true

require "minitest"
require "forwardable"

module Calificador
  # Mixin for unit tests
  module TestMixin
    extend Forwardable
    requires_ancestor Kernel, ::Minitest::Test

    Key = Calificador::Key

    # Class methods for unit tests
    module ClassMethods
      extend Forwardable
      requires_ancestor Kernel, Module

      sig { params(reporter: ::Minitest::AbstractReporter).void }
      def run_all_tests(reporter: ::MiniTest::CompositeReporter.new)
        T.cast(self, T.class_of(::Minitest::Test)).runnable_methods.each do |method|
          T.cast(self, T.class_of(::Minitest::Test)).run_one_method(self, method, reporter)
        end
      end

      sig { params(subject_class: Module, description_or_trait_or_init: T.untyped).void }
      def examines(subject_class, *description_or_trait_or_init)
        context = @__calificador_root_context if instance_variable_defined?(:@__calificador_root_context)

        if context
          raise <<~MESSAGE.gsub("\n", " ")
            Cannot specify 'examines' after a test context has been defined. The 'examines' statement should be the first statement in your test class
          MESSAGE
        end

        arguments = Context::BasicContext.extract_arguments(
          subject_key: Key[subject_class],
          values: description_or_trait_or_init,
          keywords: %i[description trait init]
        )

        description = arguments.description || __default_instance_description(subject_key: arguments.subject_key)

        context = Context::TestRoot.new(
          test_class: T.cast(self, TestClassType),
          subject_key: arguments.subject_key,
          description: description
        )

        @__calificador_root_context = T.let(context, T.nilable(Context::TestRoot))
      end

      def_delegators :__calificador_current_context, :factory, :mock
      def_delegators :__calificador_current_context, :type, :examine, :operation, :with, :without, :where
      def_delegators :__calificador_current_context, :must, :must_fail
      def_delegators :__calificador_current_context, :args, :props

      sig { params(block: T.proc.void).void }
      def body(&block)
        class_eval(&T.unsafe(block))
      end

      sig { params(subject_key: Key).returns(String) }
      def __default_type_description(subject_key:)
        description = subject_key.type.name_without_common_parents(base: T.cast(self, Module))
        description || raise("Cannot create a type description for anonymous types")
      end

      sig { params(subject_key: Key).returns(String) }
      def __default_instance_description(subject_key:)
        description = StringIO.new

        description << subject_key.type.name_without_common_parents(base: T.cast(self, Module))
        description << "(" << subject_key.trait.to_s.gsub("_", " ") << ")" if subject_key.trait?

        description.string
      end

      sig { params(subject_key: Key).returns(Symbol) }
      def __default_factory_name(subject_key:)
        description = StringIO.new

        base_name = subject_key.type.base_name || raise("Cannot create a factory name for anonymous types")

        description << base_name.snake_case
        description << "_" << subject_key.trait.to_s if subject_key.trait?

        description.string.to_sym
      end

      sig { returns(Context::TestRoot) }
      def __root_context
        if !instance_variable_defined?(:@__calificador_root_context) || @__calificador_root_context.nil?
          subject_key = __calificador_guess_subject_key

          @__calificador_root_context = Context::TestRoot.new(
            test_class: T.cast(self, TestClassType),
            subject_key: subject_key,
            description: __default_instance_description(subject_key: subject_key)
          )
        end

        @__calificador_root_context
      end

      sig { params(stack_marker: String, environment: Context::TestEnvironment).void }
      def __register_current_environment(stack_marker:, environment:)
        __calificador_test_lock.synchronize do
          if __calificador_test_environments.key?(stack_marker)
            raise KeyError, "Test run #{stack_marker} already registered"
          end

          __calificador_test_environments[stack_marker] = environment
        end
      end

      sig { params(stack_marker: String).void }
      def __unregister_current_environment(stack_marker:)
        __calificador_test_lock.synchronize do
          if __calificador_test_environments.delete(stack_marker).nil?
            raise KeyError, "Could not unregister test #{stack_marker}"
          end
        end
      end

      sig { returns(Context::TestEnvironment) }
      def __current_test_environment
        __calificador_test_lock.synchronize do
          location = ::Kernel.caller_locations&.find do |l|
            %r{\Acalificador_test_[a-zA-Z0-9_]+\z} =~ l.path
          end

          raise StandardError, "Could not find current test run in call stack" unless location

          path = T.must(location.path)

          __calificador_test_environments.fetch(path) do
            raise KeyError, "No test run registered for #{path}"
          end
        end
      end

      sig { params(context: Context::BasicContext, block: T.proc.void).void }
      def __calificador_configure(context:, block:)
        __calificador_push_context(context)

        begin
          class_exec(&block)
        ensure
          __calificador_pop_context
        end
      end

      T::Sig::WithoutRuntime.sig { params(name: Symbol).void }
      def method_added(name)
        if !name.start_with?("test_: ") && __calificador_contexts.size > 1
          raise "Adding methods (#{name}) to tests is not supported here"
        end

        super
      end

      protected

      sig { returns(T::Array[Context::BasicContext]) }
      def __calificador_contexts
        contexts = @__calificador_contexts if instance_variable_defined?(:@__calificador_contexts)

        unless contexts
          contexts = [__root_context]
          @__calificador_contexts = T.let(contexts, T.nilable(T::Array[Context::BasicContext]))
        end

        contexts
      end

      sig { params(context: Context::BasicContext).returns(Context::BasicContext) }
      def __calificador_push_context(context)
        __calificador_contexts.push(context)
        context
      end

      sig { returns(Context::BasicContext) }
      def __calificador_pop_context
        raise "Cannot remove root context" unless __calificador_contexts.size > 1

        T.must(__calificador_contexts.pop)
      end

      sig { returns(Context::BasicContext) }
      def __calificador_current_context
        T.must(__calificador_contexts.last)
      end

      sig { returns(T::Hash[String, Context::TestEnvironment]) }
      def __calificador_test_environments
        environments = @__calificador_test_environments if instance_variable_defined?(:@__calificador_test_environments)

        unless environments
          environments = {}
          @__calificador_test_environments = T.let(environments,
                                                   T.nilable(T::Hash[String, Context::TestEnvironment]))
        end

        environments
      end

      sig { returns(Mutex) }
      def __calificador_test_lock
        lock = @__calificador_test_lock if instance_variable_defined?(:@__calificador_test_lock)

        unless lock
          lock = Mutex.new
          @__calificador_test_lock = T.let(lock, T.nilable(Mutex))
        end

        lock
      end

      sig { returns(Key) }
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

    mixes_in_class_methods(ClassMethods)

    T::Sig::WithoutRuntime.sig { params(name: Symbol).void }
    def singleton_method_added(name)
      raise "Adding singleton methods (#{name}) to tests is not supported here" if __current_test_environment?

      super
    end

    def_delegator :__current_test_environment, :subject
    def_delegator :__current_test_environment, :create

    sig { params(context: Context::TestMethod).void }
    def __run_test(context:)
      stack_marker = "calificador_test_#{SecureRandom.uuid.gsub("-", "_")}"

      environment = Context::TestEnvironment.new(parent: context, test_instance: T.cast(self, TestType))
      __register_current_environment(stack_marker: stack_marker, environment: environment)

      begin
        instance_eval(<<~METHOD, __FILE__, __LINE__ + 1)
          environment.run_test
        METHOD
      ensure
        __unregister_current_environment(stack_marker: stack_marker)
      end
    end

    protected

    sig { params(stack_marker: String, environment: Context::TestEnvironment).void }
    def __register_current_environment(stack_marker:, environment:)
      @__calificador_current_test_environment = T.let(environment, T.nilable(Context::TestEnvironment))
      Calificador::Test.__register_current_environment(stack_marker: stack_marker, environment: environment)
    end

    sig { params(stack_marker: String).void }
    def __unregister_current_environment(stack_marker:)
      if !instance_variable_defined?(:@__calificador_current_test_environment) || @__calificador_current_test_environment.nil?
        raise StandardError, "No current test run registered"
      end

      Calificador::Test.__unregister_current_environment(stack_marker: stack_marker)
      @__calificador_current_test_environment = nil
    end

    sig { returns(Context::TestEnvironment) }
    def __current_test_environment
      if !instance_variable_defined?(:@__calificador_current_test_environment) || @__calificador_current_test_environment.nil?
        raise StandardError, "No current test run registered"
      end

      @__calificador_current_test_environment
    end

    sig { returns(T::Boolean) }
    def __current_test_environment?
      instance_variable_defined?(:@__calificador_current_test_environment) || !@__calificador_current_test_environment
    end
  end
end
