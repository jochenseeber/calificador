# frozen_string_literal: true

require "minitest"

using Calificador::Util::CoreExtensions

module Calificador
  # Mixin for unit tests
  module TestMixin
    Key = Calificador::Key

    class << self
      def included(includer)
        includer.extend(ClassMethods)
      end

      def prepended(prepender)
        prepender.extend(ClassMethods)
      end
    end

    def __run_test(test_method:)
      stack_marker = "calificador_test_#{SecureRandom.uuid.gsub("-", "_")}"

      __register_current_run(stack_marker: stack_marker, test_method: test_method)

      begin
        instance_eval(<<~METHOD, stack_marker, 1)
          test_method.run_test(test: self)
        METHOD
      ensure
        __unregister_current_run(stack_marker: stack_marker)
      end
    end

    protected

    TestRun = Struct.new(:test_instance, :test_method, keyword_init: true)

    def __register_current_run(stack_marker:, test_method:)
      @__calificador_current_test_run = TestRun.new(test_instance: self, test_method: test_method)
      Calificador::Test.__register_current_run(stack_marker: stack_marker, test_run: @__calificador_current_test_run)
    end

    def __unregister_current_run(stack_marker:)
      if !instance_variable_defined?(:@__calificador_current_test_run) || @__calificador_current_test_run.nil?
        raise StandardError, "No current test run registered"
      end

      Calificador::Test.__unregister_current_run(stack_marker: stack_marker)
      @__calificador_current_test_run = nil
    end

    def __current_test_run
      if !instance_variable_defined?(:@__calificador_current_test_run) || @__calificador_current_test_run.nil?
        raise StandardError, "No current test run registered"
      end

      @__calificador_current_test_run
    end

    # Class methods for unit tests
    module ClassMethods
      def run_all_tests(reporter: MiniTest::CompositeReporter.new)
        runnable_methods.each do |method|
          run_one_method(self, method, reporter)
        end
      end

      def examines(type = MISSING, trait: MISSING)
        self.__subject_type = type unless type.equal?(MISSING)
        self.__subject_trait = trait unless trait.equal?(MISSING)

        Key[__subject_type, __subject_trait]
      end

      def factory(type, description = nil, name: nil, &block)
        __root_context.dsl_config do
          factory(type, description, name: nil, &block)
        end
      end

      def examine(subject_type, description = nil, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          examine(subject_type, description, trait: trait, **values, &block)
        end
      end

      def method(method, description = nil, **values, &block)
        __root_context.dsl_config do
          method(method, description, &block)
        end
      end

      def class_method(method, description = nil, **values, &block)
        __root_context.dsl_config do
          class_method(method, description, &block)
        end
      end

      def must(description, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          must(description, trait: trait, **values, &block)
        end
      end

      def must_fail(description, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          must_fail(description, trait: trait, **values, &block)
        end
      end

      def with(description, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          with(description, trait: trait, **values, &block)
        end
      end

      def without(description, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          without(description, trait: trait, **values, &block)
        end
      end

      def where(description, trait: Key::INHERITED_TRAIT, **values, &block)
        __root_context.dsl_config do
          where(description, trait: trait, **values, &block)
        end
      end

      def body(&block)
        class_eval(&block)
      end

      def __subject_type
        if !instance_variable_defined?(:@__calificador_subject_type) || @__calificador_subject_type.nil?
          type_name = name.gsub(%r{(?<=\w)Test\z}, "")

          if Kernel.const_defined?(type_name)
            @__calificador_subject_type = Kernel.const_get(type_name)
          else
            raise StandardError, "Cannot determine test subject type from test class name '#{name}'"
          end
        end

        @__calificador_subject_type
      end

      def __subject_type=(type)
        if instance_variable_defined?(:@__calificador_subject_type) && !@__calificador_subject_type.nil?
          raise StandardError, "Cannot redefine test subject type"
        end

        @__calificador_subject_type = type
      end

      def __subject_trait
        if !instance_variable_defined?(:@__calificador_subject_trait) || @__calificador_subject_trait.nil?
          @__calificador_subject_trait = Key::DEFAULT_TRAIT
        end

        @__calificador_subject_trait
      end

      def __subject_trait=(trait)
        if instance_variable_defined?(:@__calificador_subject_trait) && !@__calificador_subject_trait.nil?
          raise StandardError, "Cannot redefine test subject trait"
        end

        @__calificador_subject_trait = trait
      end

      def __root_context
        if !instance_variable_defined?(:@__calificador_root_context) || @__calificador_root_context.nil?
          description = __subject_type.name.delete_prefix(parent_prefix)
          description = "#{description} {#{__subject_trait}}" unless __subject_trait.equal?(Key::DEFAULT_TRAIT)

          @__calificador_root_context = Spec::TestRoot.new(
            test_class: self,
            subject_key: Key[__subject_type, __subject_trait],
            description: description
          )
        end

        @__calificador_root_context
      end

      def __register_current_run(stack_marker:, test_run:)
        __calificador_test_lock.synchronize do
          raise KeyError, "Test run #{stack_marker} already registered" if __calificador_test_runs.key?(stack_marker)

          __calificador_test_runs[stack_marker] = test_run
        end
      end

      def __unregister_current_run(stack_marker:)
        __calificador_test_lock.synchronize do
          if __calificador_test_runs.delete(stack_marker).nil?
            raise KeyError, "Could not unregister test #{stack_marker}"
          end
        end
      end

      def __current_test_run
        __calificador_test_lock.synchronize do
          location = ::Kernel.caller_locations.find do |l|
            %r{\Acalificador_test_[a-zA-Z0-9_]+\z} =~ l.path
          end

          raise StandardError, "Could not find current test run in call stack" unless location

          __calificador_test_runs.fetch(location.path) do
            raise KeyError, "No test run registered for #{location.path}"
          end
        end
      end

      def __factory_methods
        @__calificador_factory_methods = Set.new unless instance_variable_defined?(:@__calificador_factory_methods)

        @__calificador_factory_methods.dup.freeze
      end

      def __define_factory_method(factory:)
        @__calificador_factory_methods = Set.new unless instance_variable_defined?(:@__calificador_factory_methods)

        if @__calificador_factory_methods.add?(factory.name)
          factory_method_name = if factory.name.to_s.start_with?("test_")
            "create_#{factory.name}"
          else
            factory.name
          end

          if method_defined?(factory_method_name, true)
            raise "Cannot define factory method #{factory_method_name}, method already exists in #{self.class}"
          end

          type = factory.key.type # rubocop:disable Lint/UselessAssignment
          trait = factory.key.trait # rubocop:disable Lint/UselessAssignment

          class_eval(<<~METHOD, factory.source_location.first, factory.source_location.last)
            define_method(factory_method_name) do
              __current_test_run.test_method.create(type: type, trait: trait)
            end
          METHOD
        end
      end

      protected

      def __calificador_test_runs
        @__calificador_test_runs = {} unless instance_variable_defined?(:@__calificador_test_runs)

        @__calificador_test_runs
      end

      def __calificador_test_lock
        @__calificador_test_lock = Mutex.new unless instance_variable_defined?(:@__calificador_test_lock)

        @__calificador_test_lock
      end
    end
  end
end
