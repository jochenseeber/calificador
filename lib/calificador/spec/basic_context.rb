# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    class BasicContext
      class Dsl
        def initialize(delegate:)
          @delegate = delegate
        end

        def factory(type, description = nil, name: nil, &block)
          key = Key[type]
          name ||= BasicContext.default_factory_name(test_class: @delegate.test_class, key: key)

          factory = Build::Factory.new(
            context: @delegate,
            key: key,
            name: name,
            description: description,
            source_location: block.source_location
          )

          factory.dsl_config(&block)
          @delegate.add_factory(factory)
        end

        def examine(subject_type, description = nil, trait: Key::DEFAULT_TRAIT, **values, &block)
          subject_key = Key[subject_type, trait == Key::INHERITED_TRAIT ? Key::DEFAULT_TRAIT : trait]
          overrides = BasicContext.collect_overrides(values: values, default_key: subject_key)

          description ||= BasicContext.default_examine_description(
            test_class: @delegate.test_class,
            subject_key: subject_key,
            values: values
          )

          context = Spec::ExamineContext.new(
            parent: @delegate,
            subject_key: subject_key,
            description: description,
            overrides: overrides
          )

          context.dsl_config(&block)

          @delegate.add_context(context, &block)
        end

        def method(method, description = nil, &block)
          context = Spec::InstanceMethodContext.new(
            parent: @delegate,
            method: method,
            description: description || "\##{method}"
          )

          context.dsl_config(&block)

          @delegate.add_context(context, &block)
        end

        def class_method(method, description = nil, &block)
          context = Spec::ClassMethodContext.new(
            parent: @delegate,
            method: method,
            description: description || ".#{method}"
          )

          context.dsl_config(&block)

          @delegate.add_context(context, &block)
        end

        def must(description, trait: Key::INHERITED_TRAIT, **values, &block)
          subject_key = @delegate.subject_key.with(trait)
          overrides = BasicContext.collect_overrides(values: values, default_key: subject_key)

          context = Spec::TestMethod.new(
            parent: @delegate,
            subject_key: subject_key,
            description: "must #{description}",
            overrides: overrides,
            expected_to_fail: false,
            body: block
          )

          @delegate.add_context(context)
        end

        def must_fail(description, trait:, **values, &block)
          subject_key = @delegate.subject_key.with(trait)
          overrides = BasicContext.collect_overrides(values: values, default_key: subject_key)

          context = Spec::TestMethod.new(
            parent: @delegate,
            subject_key: subject_key,
            description: "must fail #{description}",
            overrides: overrides,
            expected_to_fail: true,
            body: block
          )

          @delegate.add_context(context)
        end

        def with(description, trait: Key::INHERITED_TRAIT, **values, &block)
          __condition(conjunction: "with", description: description, trait: trait, values: values, &block)
        end

        def without(description, trait: Key::INHERITED_TRAIT, **values, &block)
          __condition(conjunction: "without", description: description, trait: trait, values: values, &block)
        end

        def where(description, trait: Key::INHERITED_TRAIT, **values, &block)
          __condition(conjunction: "where", description: "description", trait: trait, values: values, &block)
        end

        protected

        def __condition(conjunction:, description:, trait: Key::INHERITED_TRAIT, values: {}, &block)
          if description.is_a?(Symbol) && trait == Key::INHERITED_TRAIT
            trait = description
            description = nil
          end

          subject_key = @delegate.subject_key.with(trait)
          overrides = BasicContext.collect_overrides(values: values, default_key: subject_key)

          description ||= __default_description(key: subject_key)

          context = Spec::ConditionContext.new(
            parent: @delegate,
            subject_key: subject_key,
            description: description,
            overrides: overrides
          )

          context.dsl_config(&block)

          @delegate.add_context(context, &block)
        end

        def __default_description(key:)
          raise "Please provide a description or a trait" if key.trait == Key::INHERITED_TRAIT

          factory = @delegate.lookup_factory(key: key)

          raise "No factory defined for #{key}" if factory.nil?

          factory.description
        end
      end

      class << self
        def default_factory_name(test_class:, key:)
          name = key.type.name.delete_prefix(test_class.parent_prefix).gsub("::", "").snake_case

          name = "#{name}_#{key.trait}" if key.trait?

          name.to_sym
        end

        def default_examine_description(test_class:, subject_key:, values:)
          description = StringIO.new
          description << subject_key.type.name.delete_prefix(test_class.parent_prefix)

          description << " (" << subject_key.trait.to_s.gsub("_", " ") << ")" if subject_key.trait?

          append_values_description(description: description, values: values)

          description.string
        end

        def collect_overrides(values:, default_key:)
          result = Hash.new { |hash, key| hash[key] = ValueOverride.new(key: key) }
          default_values = {}

          values.each do |key, value|
            case key
            when Symbol
              default_values[key] = value
            when Class
              key = Key[key]
              result[key] = result[key].merge_values(value)
            when Key
              result[key] = result[key].merge_values(value)
            else
              raise ArgumentError, "Illegal override key '#{key}'"
            end
          end

          result[default_key] = result[default_key].merge_values(default_values) unless default_values.empty?
          result.default_proc = nil

          result
        end

        protected

        def append_values_description(description:, values:)
          unless values.empty?
            values.each_with_index do |(name, value), index|
              description << case index
              when 0
                " where "
              when values.size - 1
                " and "
              else
                ", "
              end

              description << name

              description << case value
              when NilClass
                "is not set"
              when TrueClass
                "is true"
              when FalseClass
                "is false"
              else
                "is set"
              end
            end
          end

          description
        end
      end

      attr_reader :description, :parent, :overrides

      def initialize(parent:, subject_key:, description:, overrides:)
        @parent = parent
        @subject_key = subject_key
        @description = description

        @children = []

        factories = overrides.map do |key, override|
          parent_factory = parent.lookup_factory(key: key)

          factory = Build::Factory.new(
            parent: parent_factory,
            context: self,
            key: key,
            name: parent_factory&.name || BasicContext.default_factory_name(test_class: test_class, key: key),
            source_location: Kernel.caller_locations(0, 1).first
          )

          factory.add_values(override.values)

          factory
        end

        @factories = factories.map { |f| [f.key, f] }.to_h
        @named_factories = factories.map { |f| [f.name, f] }.to_h
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
        parent&.test_class || raise(StandardError, "No parent context defines a test class")
      end

      def subject_key
        @subject_key || (parent.subject_key unless subtree_root? || parent.nil?)
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
        result = self
        result = result.parent until result.parent.nil?
        result
      end

      def add_factory(factory)
        raise KeyError, "Factory for type #{factory.key.type} already defined" if @factories.key?(factory.key.type)
        raise KeyError, "Factory with name #{factory.name} already defined" if @named_factories.key?(factory.name)

        @factories[factory.key] = factory
        @named_factories[factory.name] = factory

        test_class.__define_factory_method(factory: factory)
      end

      def factories
        @factories.dup.freeze
      end

      def named_factories
        @named_factories.dup.freeze
      end

      def lookup_factory(key:)
        @factories[key] || @parent&.lookup_factory(key: key)
      end

      def lookup_named_factory(name:)
        @named_factories[name] || @parent&.lookup_named_factory(name: name)
      end

      def create_subject(environment:, subject_key:)
        @parent.create_subject(environment: environment, subject_key: subject_key)
      end

      def create_result(subject:, arguments:, options:, block:)
        @parent.create_result(subject: subject, arguments: arguments, options: options, block: block)
      end

      protected

      def effective_overrides
        context_path.each_with_object({}) do |context, overrides|
          overrides.merge!(context.overrides) do |_key, existing_override, additional_override|
            existing_override.merge(additional_override)
          end
        end
      end

      def add_context_to_path(path, subtree: true)
        @parent.add_context_to_path(path, subtree: subtree) unless @parent.nil? || (subtree && subtree_root?)

        path << self
      end

      def separate_description_by_space?
        true
      end
    end
  end
end
