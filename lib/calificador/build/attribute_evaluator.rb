# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Build
    class AttributeEvaluator
      EVALUATING = Object.new.freeze

      class Proxy
        def initialize(delegate:)
          @delegate = delegate
        end

        def create(type, trait = nil)
          key = Key[type, trait]
          @delegate.create_object(key: key)
        end

        def respond_to_missing?(method, include_all)
          @delegate.attribute?(name: method) ? true : super
        end

        def method_missing(method, *arguments, &block)
          if @delegate.attribute?(name: method)
            raise ArgumentError, "Getter must not be called with arguments" unless arguments.empty?

            @delegate.value(name: method)
          else
            super
          end
        end
      end

      attr_reader :attributes, :values

      def initialize(context:)
        @context = context
        @attributes = {}
        @values = {}
        @proxy = Proxy.new(delegate: self)
      end

      def create_object(key:)
        @context.create_object(key: key)
      end

      def add_values(values)
        @values.merge!(values)
      end

      def add_attributes(attributes)
        attributes.each do |attribute|
          @attributes[attribute.name] = attribute
        end
      end

      def value(name:)
        result = @values.fetch(name) do
          @values[name] = EVALUATING

          begin
            config = @attributes.fetch(name).config
            @values[name] = evaluate(&config)
          rescue StandardError
            @values.delete(name)
            raise
          end
        end

        raise StandardError, "Endless recursion while evaluating attribute #{name}" if result == EVALUATING

        result
      end

      def evaluate(*arguments, **options, &block)
        block.invoke_with_target(@proxy, *arguments, **options)
      end

      def attribute?(name:)
        @attributes.key?(name)
      end
    end
  end
end
