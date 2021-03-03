# frozen_string_literal: true

require "forwardable"
require "ostruct"

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    class BasicContext
      extend Forwardable

      class << self
        def extract_arguments(subject_key:, values:, names:)
          arguments = OpenStruct.new
          arguments.overrides = [] if names.include?(:overrides)
          arguments.subject_key = subject_key

          values.each_with_index do |value, value_index|
            name_index = names.index do |name|
              case name
              when :type
                value.is_a?(Module)
              when :trait
                value.is_a?(Symbol)
              when :name
                value.is_a?(Symbol)
              when :description
                value.is_a?(String)
              when :init
                value.is_a?(Proc)
              when :overrides
                value.is_a?(Override::BasicOverride)
              else
                raise ArgumentError, "Unknown option '#{name}'"
              end
            end

            unless name_index
              raise ArgumentError, "Illegal argument at position #{value_index} for (#{values.join(", ")})"
            end

            name = names[name_index]

            case name
            when :type
              arguments.subject_key = Key[value, arguments.subject_key.trait]
            when :trait
              arguments.subject_key = Key[arguments.subject_key.type, value]
            when :overrides
              arguments.overrides << value
            when :init
              arguments.overrides << Override::FactoryOverride.new(key: arguments.subject_key, function: value)
            else
              arguments[name] = value
            end

            if name == :overrides
              names.shift(name_index)
            else
              names.shift(name_index + 1)
            end
          end

          arguments
        end
      end

      attr_reader :description, :parent, :call_context, :operation_arguments

      def initialize(parent:, subject_key:, description:, overrides: [])
        raise ArgumentError, "Parent must be a #{BasicContext}" unless parent.nil? || parent.is_a?(BasicContext)
        raise ArgumentError, "Subject key must be a #{Key}" unless subject_key.is_a?(Key)

        @parent = parent
        @subject_key = subject_key
        @description = description

        @children = []
        @factories = {}
        @named_factories = {}

        @operation_name = nil
        @operation_arguments = parent&.operation_arguments.dup || {}

        overrides.map do |override|
          check_override(value: override)
        end.map do |override|
          override.apply(context: self)
        end
      end

      def setup; end

      def subtree_root?
        false
      end

      def add_context(context, &block)
        @children << context

        context.setup
      end

      def test_class
        @test_class ||= (@parent&.test_class || raise(StandardError, "No parent context defines a test class"))
      end

      def subject_key
        @subject_key ||= begin
          @parent&.subject_key || raise(StandardError, "No parent context defines a subject class")
        end
      end

      def context_path(subtree: true)
        add_context_to_path([], subtree: subtree).freeze
      end

      def full_description
        context_path.reduce(StringIO.new) do |description, context|
          description << " " if description.length.positive? && context.separate_description_by_space?
          description << context.description
        end.string
      end

      def root
        @parent&.root || self
      end

      def operation_name
        @operation_name ||= Util::Nil[@parent&.operation_name]
        @operation_name.unmask_nil
      end

      def add_factory(factory)
        raise KeyError, "Factory for type #{factory.key.type} already defined" if @factories.key?(factory.key.type)
        raise KeyError, "Factory with name #{factory.name} already defined" if @named_factories.key?(factory.name)

        @factories[factory.key] = factory
        @named_factories[factory.name] = factory
      end

      def factories
        @factories.dup.freeze
      end

      def named_factories
        @named_factories.dup.freeze
      end

      def lookup_factory(key:, inherited: true)
        @factories[key] || (@parent&.lookup_factory(key: key) if inherited)
      end

      def lookup_named_factory(name:)
        @named_factories[name] || @parent&.lookup_named_factory(name: name)
      end

      def override_factory(key:)
        lookup_factory(key: key, inherited: false) || begin
          parent_factory = @parent&.lookup_factory(key: key)

          factory = Build::ObjectFactory.new(
            parent: parent_factory,
            context: self,
            key: key,
            name: parent_factory&.name || test_class.__default_factory_name(subject_key: key),
            source_location: Kernel.caller_locations.first { |l| !l.first.start_with(Calificador::BASE_DIR.to_s) }
          )

          add_factory(factory)
          factory
        end
      end

      def arguments(&block)
        Override::ArgumentOverride.new.config(&block)
      end

      def_delegator :self, :arguments, :args

      def properties(type = nil, trait = Key::DEFAULT_TRAIT, &block)
        key = Key[type || subject_key.type, trait]

        Override::PropertyOverride.new(key: key).config(&block)
      end

      def_delegator :self, :properties, :props

      def factory(type, *description_or_name, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: Key[type],
          values: description_or_name,
          names: %i[description name]
        )

        arguments.name ||= test_class.__default_factory_name(subject_key: arguments.subject_key)
        arguments.description ||= test_class.__default_instance_description(subject_key: arguments.subject_key)

        factory = Build::ObjectFactory.new(
          context: self,
          key: arguments.subject_key,
          name: arguments.name,
          description: arguments.description,
          source_location: block&.source_location
        )

        factory.dsl.instance_exec(&block) unless block.nil?

        add_factory(factory)
      end

      def mock(type, *description_or_name, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: Key[type],
          values: description_or_name,
          names: %i[description name]
        )

        arguments.name ||= test_class.__default_factory_name(subject_key: arguments.subject_key)
        arguments.description ||= test_class.__default_instance_description(subject_key: arguments.subject_key)

        mock = Build::MockFactory.new(
          context: self,
          key: arguments.subject_key,
          name: arguments.name,
          description: arguments.description,
          source_location: block&.source_location
        )

        mock.dsl.instance_exec(&block) unless block.nil?

        add_factory(mock)
      end

      def type(*type_or_description_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: type_or_description_or_overrides,
          names: %i[type description overrides]
        )

        arguments.description ||= test_class.__default_type_description(subject_key: arguments.subject_key)

        context = Context::TypeContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: arguments.description,
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      def examine(*type_or_trait_or_description_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: type_or_trait_or_description_or_init_or_overrides,
          names: %i[type trait description init overrides]
        )

        arguments.description ||= arguments.subject_key.to_s(base_module: test_class)

        context = Context::InstanceContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: arguments.description,
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      def operation(operation, *trait_or_description_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_description_or_init_or_overrides,
          names: %i[trait description init overrides]
        )

        arguments.description ||= "\##{operation}"

        context = Context::OperationContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          name: operation,
          description: arguments.description,
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      def must(description, *trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_init_or_overrides,
          names: %i[trait init overrides]
        )

        context = Context::TestMethod.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: "must #{description}",
          overrides: arguments.overrides,
          expected_to_fail: false,
          body: block
        )

        add_context(context)
      end

      def must_fail(description, *trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_init_or_overrides,
          names: %i[trait init overrides]
        )

        context = Context::TestMethod.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: "must fail #{description}",
          overrides: arguments.overrides,
          expected_to_fail: true,
          body: block
        )

        add_context(context)
      end

      def with(*description_or_trait_or_init_or_overrides, &block)
        condition("with", *description_or_trait_or_init_or_overrides, &block)
      end

      def without(*description_or_trait_or_init_or_overrides, &block)
        condition("without", *description_or_trait_or_init_or_overrides, &block)
      end

      def where(*description_or_trait_or_init_or_overrides, &block)
        condition("where", *description_or_trait_or_init_or_overrides, &block)
      end

      def create_subject(environment:)
        raise "No context defines a text subject" unless parent

        parent.create_subject(environment: environment)
      end

      def merge_operation_arguments(arguments)
        @operation_arguments.merge!(arguments)
      end

      protected

      def configure(block:)
        test_class.__calificador_configure(context: self, block: block)
      end

      def condition(conjunction, *description_or_trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: description_or_trait_or_init_or_overrides,
          names: %i[description trait init overrides]
        )

        arguments.description ||= begin
          raise ArgumentError, "Please provide a description if you override values" unless arguments.overrides.empty?

          arguments.subject_key.to_s
        end

        context = Context::ConditionContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: [conjunction, arguments.description].compact.join(" "),
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      def add_context_to_path(path, subtree: true)
        @parent.add_context_to_path(path, subtree: subtree) unless @parent.nil? || (subtree && subtree_root?)

        path << self
      end

      def separate_description_by_space?
        true
      end

      def check_override(value:)
        raise ArgumentError, "Illegal override type #{value.class}" unless value.is_a?(Override::BasicOverride)

        value
      end
    end
  end
end
