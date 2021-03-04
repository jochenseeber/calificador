# typed: strict
# frozen_string_literal: true

require "forwardable"
require "ostruct"

module Calificador
  module Context
    class BasicContext
      abstract!

      extend Forwardable

      class Arguments < T::Struct
        prop :subject_key, Key
        prop :name, T.nilable(Symbol)
        prop :description, T.nilable(String)
        prop :overrides, T::Array[Override::BasicOverride]
      end

      class << self
        sig do
          params(
            subject_key: Key,
            values: T::Array[BasicObject],
            keywords: T::Array[Symbol]
          ).returns(Arguments)
        end
        def extract_arguments(subject_key:, values:, keywords:)
          arguments = Arguments.new(subject_key: subject_key, overrides: [])

          Util::ArgumentMatcher.new(keywords: keywords, values: values).process do |matcher, value|
            case value
            when Module
              matcher.accept(:type)
              arguments.subject_key = Key[value, arguments.subject_key.trait]
            when Symbol
              keyword = matcher.accept(:name, :trait)
              case keyword
              when :name
                arguments.name = value
              when :trait
                arguments.subject_key = Key[arguments.subject_key.type, value]
              end
            when String
              matcher.accept(:description)
              arguments.description = value
            when Proc
              matcher.accept(:init)
              override = Override::FactoryOverride.new(key: arguments.subject_key, function: T.cast(value, InitProc))
              arguments.overrides << override
            when Override::BasicOverride
              matcher.accept(:overrides, consume: false)
              arguments.overrides << value
            else
              matcher.reject
            end
          end

          arguments
        end
      end

      sig { returns(Key) }
      attr_reader :subject_key

      sig { returns(String) }
      attr_reader :description

      sig { returns(T.nilable(BasicContext)) }
      attr_reader :parent

      sig { returns(ArgumentHash) }
      attr_reader :operation_arguments

      sig do
        params(
          parent: T.nilable(BasicContext),
          subject_key: Key,
          description: String,
          overrides: T::Array[Override::BasicOverride]
        ).void
      end
      def initialize(parent:, subject_key:, description:, overrides: [])
        @parent = T.let(parent, T.nilable(BasicContext))
        @subject_key = T.let(subject_key, Key)
        @description = T.let(description, String)

        @test_class = T.let(nil, T.nilable(TestClassType))
        @children = T.let([], T::Array[BasicContext])
        @factories = T.let({}, T::Hash[Key, Build::BasicFactory])
        @named_factories = T.let({}, T::Hash[Symbol, Build::BasicFactory])

        @operation_name = T.let(nil, T.nilable(T.any(Symbol, Util::Nil)))
        @operation_arguments = T.let(parent&.operation_arguments.dup || {}, ArgumentHash)

        overrides.each do |override|
          override.apply(context: self)
        end
      end

      sig { void }
      def setup; end

      sig { returns(T::Boolean) }
      def subtree_root?
        false
      end

      sig { params(context: BasicContext).void }
      def add_context(context)
        @children << context

        context.setup
      end

      sig { params(subtree: T::Boolean).returns(T::Array[BasicContext]) }
      def context_path(subtree: true)
        add_context_to_path([], subtree: subtree).freeze
      end

      sig { returns(String) }
      def full_description
        context_path.reduce(StringIO.new) do |description, context|
          description << " " if description.length.positive? && context.separate_description_by_space?
          description << context.description
        end.string
      end

      sig { returns(BasicContext) }
      def root
        @parent&.root || self
      end

      sig { returns(T.nilable(Symbol)) }
      def operation_name
        @operation_name ||= Util::Nil[@parent&.operation_name]
        @operation_name.unmask_nil
      end

      sig { params(factory: Build::BasicFactory).void }
      def add_factory(factory)
        raise KeyError, "Factory for type #{factory.key.type} already defined" if @factories.key?(factory.key)
        raise KeyError, "Factory with name #{factory.name} already defined" if @named_factories.key?(factory.name)

        @factories[factory.key] = factory
        @named_factories[factory.name] = factory
      end

      sig { returns(T::Hash[Key, Build::BasicFactory]) }
      def factories
        @factories.dup.freeze
      end

      sig { returns(T::Hash[Symbol, Build::BasicFactory]) }
      def named_factories
        @named_factories.dup.freeze
      end

      sig { params(key: Key, inherited: T::Boolean).returns(T.nilable(Build::BasicFactory)) }
      def lookup_factory(key:, inherited: true)
        @factories[key] || (@parent&.lookup_factory(key: key) if inherited)
      end

      sig { params(name: Symbol).returns(T.nilable(Build::BasicFactory)) }
      def lookup_named_factory(name:)
        @named_factories[name] || @parent&.lookup_named_factory(name: name)
      end

      sig { params(key: Key).returns(Build::BasicFactory) }
      def override_factory(key:)
        lookup_factory(key: key, inherited: false) || begin
          parent_factory = @parent&.lookup_factory(key: key)

          factory = Build::ObjectFactory.new(
            parent: parent_factory,
            context: self,
            key: key,
            name: (parent_factory&.name || test_class.__default_factory_name(subject_key: key)).to_sym,
            source_location: Util::SourceLocation.caller_site
          )

          add_factory(factory)
          factory
        end
      end

      sig { params(block: T.proc.void).returns(Override::ArgumentOverride) }
      def arguments(&block)
        Override::ArgumentOverride.new.config(&block)
      end

      def_delegator :self, :arguments, :args

      sig do
        params(
          type: T.nilable(Module),
          trait: T.nilable(Symbol),
          block: T.proc.void
        ).returns(Override::PropertyOverride)
      end
      def properties(type = nil, trait = Key::DEFAULT_TRAIT, &block)
        key = Key[type || subject_key.type, trait]

        Override::PropertyOverride.new(key: key).config(&block)
      end

      def_delegator :self, :properties, :props

      sig do
        params(
          type: Module,
          description_or_name: T.any(String, Symbol),
          block: T.nilable(T.proc.void)
        ).returns(Build::BasicFactory)
      end
      def factory(type, *description_or_name, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: Key[type],
          values: description_or_name,
          keywords: %i[description name]
        )

        name = arguments.name || test_class.__default_factory_name(subject_key: arguments.subject_key)
        description = arguments.description || test_class.__default_instance_description(subject_key: arguments.subject_key)

        factory = Build::ObjectFactory.new(
          context: self,
          key: arguments.subject_key,
          name: name,
          description: description,
          source_location: block&.source_site
        )

        factory.dsl.instance_exec(&T.unsafe(block)) unless block.nil?

        add_factory(factory)
        factory
      end

      sig do
        params(
          type: Module,
          description_or_name: T.any(String, Symbol),
          block: T.nilable(T.proc.void)
        ).returns(Build::BasicFactory)
      end
      def mock(type, *description_or_name, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: Key[type],
          values: description_or_name,
          keywords: %i[description name]
        )

        name = arguments.name || test_class.__default_factory_name(subject_key: arguments.subject_key)
        description = arguments.description || test_class.__default_instance_description(
          subject_key: arguments.subject_key
        )

        mock = Build::MockFactory.new(
          context: self,
          key: arguments.subject_key,
          name: name,
          description: description,
          source_location: block&.source_site
        )

        mock.dsl.instance_exec(&T.unsafe(block)) unless block.nil?

        add_factory(mock)
        mock
      end

      sig do
        params(
          type_or_description_or_overrides: T.any(Module, String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def type(*type_or_description_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: type_or_description_or_overrides,
          keywords: %i[type description overrides]
        )

        description = arguments.description || test_class.__default_type_description(subject_key: arguments.subject_key)

        context = Context::TypeContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: description,
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      sig do
        params(
          type_or_trait_or_desc_or_init_or_overrides: T.any(Module, String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def examine(*type_or_trait_or_desc_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: type_or_trait_or_desc_or_init_or_overrides,
          keywords: %i[type trait description init overrides]
        )

        context = Context::InstanceContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          description: arguments.description || arguments.subject_key.to_s(base_module: test_class),
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      sig do
        params(
          operation: Symbol,
          trait_or_desc_or_init_or_overrides: T.any(String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def operation(operation, *trait_or_desc_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_desc_or_init_or_overrides,
          keywords: %i[trait description init overrides]
        )

        description = arguments.description || "\##{operation}"

        context = Context::OperationContext.new(
          parent: self,
          subject_key: arguments.subject_key,
          name: operation,
          description: description,
          overrides: arguments.overrides
        )

        context.configure(block: block)

        add_context(context, &block)
      end

      sig do
        params(
          description: String,
          trait_or_init_or_overrides: T.any(Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def must(description, *trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_init_or_overrides,
          keywords: %i[trait init overrides]
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

      sig do
        params(
          description: String,
          trait_or_init_or_overrides: T.any(Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def must_fail(description, *trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: trait_or_init_or_overrides,
          keywords: %i[trait init overrides]
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

      sig do
        params(
          desc_or_trait_or_init_or_overrides: T.any(String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def with(*desc_or_trait_or_init_or_overrides, &block)
        T.unsafe(self).condition("with", *desc_or_trait_or_init_or_overrides, &block)
      end

      sig do
        params(
          desc_or_trait_or_init_or_overrides: T.any(String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def without(*desc_or_trait_or_init_or_overrides, &block)
        T.unsafe(self).condition("without", *desc_or_trait_or_init_or_overrides, &block)
      end

      sig do
        params(
          desc_or_trait_or_init_or_overrides: T.any(String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def where(*desc_or_trait_or_init_or_overrides, &block)
        T.unsafe(self).condition("where", *desc_or_trait_or_init_or_overrides, &block)
      end

      sig { params(environment: TestEnvironment).returns(BasicObject) }
      def create_subject(environment:)
        parent = self.parent || raise("No context defines a text subject")
        parent.create_subject(environment: environment)
      end

      sig { params(arguments: ArgumentHash).returns(ArgumentHash) }
      def merge_operation_arguments(arguments)
        @operation_arguments.merge!(arguments)
      end

      protected

      sig { params(block: T.proc.void).void }
      def configure(block:)
        test_class.__calificador_configure(context: self, block: block)
      end

      sig do
        params(
          conjunction: String,
          desc_or_trait_or_init_or_overrides: T.any(String, Symbol, Override::BasicOverride, InitProc),
          block: T.proc.void
        ).void
      end
      def condition(conjunction, *desc_or_trait_or_init_or_overrides, &block)
        arguments = BasicContext.extract_arguments(
          subject_key: subject_key,
          values: desc_or_trait_or_init_or_overrides,
          keywords: %i[description trait init overrides]
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

      sig { params(path: T::Array[BasicContext], subtree: T::Boolean).returns(T::Array[BasicContext]) }
      def add_context_to_path(path, subtree: true)
        @parent.add_context_to_path(path, subtree: subtree) unless @parent.nil? || (subtree && subtree_root?)

        path << self
      end

      sig { returns(T::Boolean) }
      def separate_description_by_space?
        true
      end

      sig { returns(TestClassType) }
      def test_class
        @test_class ||= begin
          @parent&.test_class || raise("No parent context defines a test class")
        end
      end
    end
  end
end
