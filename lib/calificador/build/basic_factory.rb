# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Build
    # Factory calss
    class BasicFactory
      # Configuration derived factories
      class Dsl < Util::ProxyObject
        attr_reader :__factory

        def initialize(factory:)
          super()

          @__factory = factory
        end

        def add_attribute(name, **properties, &config)
          type ||= __default_property_type(name: name)
          attribute = Attribute.new(name: name, type: type, config: config)
          @__factory.add_attribute(attribute)
        end

        def init_with(&block)
          raise "Initializer requires a block to create the object" if block.nil?

          @__factory.init_with = block
        end

        def before_create(&block)
          raise "Before requires a block to call" if block.nil?

          @__factory.before_create = block
        end

        def after_create(&block)
          raise "After requires a block to call" if block.nil?

          @__factory.after_create = block
        end

        def trait(trait, description = nil, &block)
          factory = __create_factory(trait: trait, description: description, source_location: block.source_location)
          factory.dsl.instance_exec(&block)
          @__factory.context.add_factory(factory)
        end

        def singleton_method_added(name) # rubocop:disable Lint/MissingSuper
          ::Kernel.raise "Adding methods (#{name}) inside factory definitions is not supported"
        end

        protected

        def __respond_to_missing?(name:, include_all:)
          name.start_with?("__") ? super : true
        end

        def __method_missing(name:, arguments:, keywords:, block:)
          if name.start_with?("__")
            super
          else
            unless arguments.empty?
              ::Kernel.raise ::ArgumentError, <<~ERROR
                Attribute '#{name}' cannot have arguments. Please use a block to configure the value
              ERROR
            end

            ::Kernel.raise ::ArgumentError, "Attribute '#{name}' must have a block to provide the value" if block.nil?

            add_attribute(name, &block)
          end
        end

        def __default_trait_description(trait:)
          trait.to_s.gsub("_", " ").chomp
        end

        def __create_factory(trait:, description:, source_location:)
          raise NotImplementedError, "Subclasses must implement"
        end

        def __default_property_type(name:)
          raise NotImplementedError, "Subclasses must implement"
        end
      end

      attr_reader :parent, :description, :key, :context, :name, :source_location
      attr_accessor :init_with, :before_create, :after_create

      def initialize(context:, parent: nil, key:, name:, description: nil, source_location:)
        raise "Parent factory must have same type" unless parent.nil? || parent.key.type == key.type

        @context = context
        @key = key
        @name = name.to_sym
        @source_location = source_location
        @parent = parent
        @description = description.dup.freeze
        @attributes = {}
        @init_with = nil
        @before_create = nil
        @after_create = nil
      end

      def create(environment:)
        evaluator = AttributeEvaluator.new(environment: environment)

        collect_attributes(evaluator: evaluator)

        exec_before_create(evaluator: evaluator)

        object = create_object(evaluator: evaluator)

        set_properties(object: object, evaluator: evaluator)

        exec_after_create(evaluator: evaluator, object: object)

        object
      end

      def attributes
        @attributes.dup.freeze
      end

      def attribute(name:)
        @attributes[name]
      end

      def add_attribute(attribute)
        raise KeyError, "Duplicate attribute name #{attribute.name}" if @attributes.key?(attribute.name)

        @attributes[attribute.name] = attribute
      end

      def add_overrides(overrides)
        overrides.each do |name, value|
          current_attribute = @parent&.lookup_attribute(name: name)

          attribute = Attribute.new(name: name, type: current_attribute&.type || :property, config: value)
          add_attribute(attribute)
        end
      end

      def lookup_attribute(name:)
        @attributes[name] || @parent&.lookup_attribute(name: name)
      end

      def dsl
        self.class.const_get(:Dsl).new(factory: self)
      end

      protected

      def collect_attributes(evaluator:)
        @parent&.collect_attributes(evaluator: evaluator)
        evaluator.add_attributes(@attributes.values)
      end

      def exec_before_create(evaluator:)
        @parent&.exec_before_create(evaluator: evaluator)
        evaluator.evaluate(&@before_create) unless @before_create.nil?
      end

      def exec_after_create(evaluator:, object:)
        @parent&.exec_after_create(evaluator: evaluator, object: object)
        evaluator.evaluate(object, &@after_create) unless @after_create.nil?
      end

      def nearest_init_with
        @init_with || @parent&.nearest_init_with
      end

      def create_object(evaluator:)
        init_with = nearest_init_with

        if init_with.nil?
          instantiate_object(evaluator: evaluator)
        else
          evaluator.evaluate(&init_with)
        end
      end

      def set_properties(object:, evaluator:)
        evaluator.attributes.each_value do |attribute|
          object.send(:"#{attribute.name}=", evaluator.value(name: attribute.name)) if attribute.type == :property
        end
      end

      def instantiate_object(evaluator:)
        raise "Cannot instantiate #{@key} without init function"
      end
    end
  end
end
