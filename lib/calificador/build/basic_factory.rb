# typed: strict
# frozen_string_literal: true

module Calificador
  module Build
    # Factory calss
    class BasicFactory
      # Configuration derived factories
      class Dsl < Util::OvertProxyObject
        ::T::Helpers.abstract!

        PROTECTED_METHODS = ::T.let(%i[is_a? class], ::T::Array[::Symbol])

        sig { returns(BasicFactory) }
        attr_reader :__factory

        sig { params(factory: BasicFactory).void }
        def initialize(factory:)
          super()

          @__factory = factory
        end

        sig { params(name: ::Symbol, properties: ::BasicObject, config: ::T.proc.returns(::BasicObject)).void }
        def add_attribute(name, **properties, &config)
          type ||= __default_property_type(name: name)
          attribute = Attribute.new(name: name, type: type, config: config)
          @__factory.add_attribute(attribute)
        end

        sig { params(block: ::T.nilable(::T.proc.returns(::BasicObject))).void }
        def init_with(&block)
          ::Kernel.raise "Initializer requires a block to create the object" if block.nil?

          @__factory.init_with = block
        end

        sig { params(block: ::T.nilable(::T.proc.void)).void }
        def before_create(&block)
          ::Kernel.raise "Before requires a block to call" if block.nil?

          @__factory.before_create = block
        end

        sig { params(block: ::T.nilable(::Proc)).void }
        def after_create(&block)
          ::Kernel.raise "After requires a block to call" if block.nil?

          @__factory.after_create = block
        end

        sig { params(trait: ::Symbol, description: ::T.nilable(::String), block: ::T.proc.void).void }
        def trait(trait, description = nil, &block)
          factory = __create_factory(trait: trait, description: description, source_location: block.source_site)
          factory.dsl.instance_exec(&::T.unsafe(block))
          @__factory.context.add_factory(factory)
        end

        ::T::Sig::WithoutRuntime.sig { params(name: Symbol).void }
        def singleton_method_added(name) # rubocop:disable Lint/MissingSuper
          ::Kernel.raise "Adding methods (#{name}) inside factory definitions is not supported"
        end

        protected

        sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
        def __respond_to_missing?(name:, include_all:)
          name.start_with?("__") ? super : true
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
          if name.start_with?("__") || PROTECTED_METHODS.include?(name)
            super
          else
            unless arguments.empty?
              ::Kernel.raise ::ArgumentError, <<~ERROR
                Attribute '#{name}' cannot have arguments. Please use a block to configure the value
              ERROR
            end

            ::Kernel.raise ::ArgumentError, "Attribute '#{name}' must have a block to provide the value" if block.nil?

            add_attribute(name, &::T.cast(block, InitProc))
          end
        end

        ruby2_keywords :__method_missing

        sig { params(trait: ::Symbol).returns(::String) }
        def __default_trait_description(trait:)
          trait.to_s.gsub("_", " ").chomp
        end

        sig do
          abstract.params(
            trait: ::Symbol,
            description: ::T.nilable(::String),
            source_location: ::T.nilable(Util::SourceLocation)
          ).returns(BasicFactory)
        end
        def __create_factory(trait:, description:, source_location:); end

        sig { abstract.params(name: ::Symbol).returns(::Symbol) }
        def __default_property_type(name:); end
      end

      sig { returns(T.nilable(BasicFactory)) }
      attr_reader :parent

      sig { returns(T.nilable(String)) }
      attr_reader :description

      sig { returns(Key) }
      attr_reader :key

      sig { returns(Context::BasicContext) }
      attr_reader :context

      sig { returns(Symbol) }
      attr_reader :name

      sig { returns(Util::SourceLocation) }
      attr_reader :source_location

      sig { returns(T.nilable(T.proc.returns(BasicObject))) }
      attr_accessor :init_with

      sig { returns(T.nilable(T.proc.void)) }
      attr_accessor :before_create

      sig { returns(T.nilable(Proc)) }
      attr_accessor :after_create

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
        raise "Parent factory must have same type" unless parent.nil? || parent.key.type == key.type

        @context = context
        @key = key
        @name = T.let(name, Symbol)
        @source_location = T.let(source_location || Util::SourceLocation.unknown, Util::SourceLocation)
        @parent = parent
        @description = T.let(description.dup.freeze, T.nilable(String))
        @attributes = T.let({}, T::Hash[Symbol, Attribute])
        @init_with = T.let(nil, T.nilable(T.proc.returns(BasicObject)))
        @before_create = T.let(nil, T.nilable(T.proc.void))
        @after_create = T.let(nil, T.nilable(Proc))
      end

      sig { params(environment: Context::TestEnvironment).returns(BasicObject) }
      def create(environment:)
        evaluator = AttributeEvaluator.new(key: @key, environment: environment)

        collect_attributes(evaluator: evaluator)

        exec_before_create(evaluator: evaluator)

        object = create_object(evaluator: evaluator)

        set_properties(object: object, evaluator: evaluator)

        exec_after_create(evaluator: evaluator, object: object)

        object
      end

      sig { returns(T::Hash[Symbol, Attribute]) }
      def attributes
        @attributes.dup.freeze
      end

      sig { params(name: Symbol).returns(T.nilable(Attribute)) }
      def attribute(name:)
        @attributes[name]
      end

      sig { params(attribute: Attribute).void }
      def add_attribute(attribute)
        raise KeyError, "Duplicate attribute name #{attribute.name}" if @attributes.key?(attribute.name)

        @attributes[attribute.name] = attribute
      end

      sig { params(overrides: T::Hash[Symbol, T.proc.returns(BasicObject)]).void }
      def add_overrides(overrides)
        overrides.each do |name, value|
          current_attribute = @parent&.lookup_attribute(name: name)

          attribute = Attribute.new(name: name, type: current_attribute&.type || :property, config: value)
          add_attribute(attribute)
        end
      end

      sig { params(name: Symbol).returns(T.nilable(Attribute)) }
      def lookup_attribute(name:)
        @attributes.fetch(name) do
          @parent&.lookup_attribute(name: name)
        end
      end

      sig { returns(BasicObject) }
      def dsl
        self.class.const_get(:Dsl).new(factory: self)
      end

      protected

      sig { params(evaluator: AttributeEvaluator).void }
      def collect_attributes(evaluator:)
        @parent&.collect_attributes(evaluator: evaluator)
        evaluator.add_attributes(@attributes.values)
      end

      sig { params(evaluator: AttributeEvaluator).void }
      def exec_before_create(evaluator:)
        @parent&.exec_before_create(evaluator: evaluator)
        evaluator.evaluate(&@before_create) unless @before_create.nil?
      end

      sig { params(evaluator: AttributeEvaluator, object: BasicObject).void }
      def exec_after_create(evaluator:, object:)
        @parent&.exec_after_create(evaluator: evaluator, object: object)
        evaluator.evaluate(object, &@after_create) unless @after_create.nil?
      end

      sig { returns(T.nilable(T.proc.returns(BasicObject))) }
      def nearest_init_with
        @init_with || @parent&.nearest_init_with
      end

      sig { params(evaluator: AttributeEvaluator).returns(BasicObject) }
      def create_object(evaluator:)
        init_with = nearest_init_with

        if init_with.nil?
          instantiate_object(evaluator: evaluator)
        else
          evaluator.evaluate(&init_with)
        end
      end

      sig { params(object: BasicObject, evaluator: AttributeEvaluator).void }
      def set_properties(object:, evaluator:)
        evaluator.attributes.each_value do |attribute|
          object.__send__(:"#{attribute.name}=", evaluator.value(name: attribute.name)) if attribute.type == :property
        end
      end

      sig { params(evaluator: AttributeEvaluator).returns(BasicObject) }
      def instantiate_object(evaluator:)
        raise "Cannot instantiate #{@key} without init function"
      end
    end
  end
end
