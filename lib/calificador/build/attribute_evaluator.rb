# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Build
    class AttributeEvaluator
      EVALUATING = Object.new.freeze

      class Proxy < Util::ProxyObject
        def initialize(evaluator:)
          super()

          @evaluator = evaluator
          @environment_proxy = evaluator.environment.proxy
        end

        protected

        def __respond_to_missing?(name:, include_all:)
          @evaluator.attribute?(name: name) || @environment_proxy.respond_to?(name)
        end

        def __method_missing(name:, arguments:, keywords:, block:)
          if @evaluator.attribute?(name: name)
            raise ArgumentError, "Getter must not be called with arguments" unless arguments.empty?

            @evaluator.value(name: name)
          else
            @environment_proxy.send(name, *arguments, **keywords, &block)
          end
        end
      end

      attr_reader :attributes, :values, :environment

      def initialize(environment:)
        @environment = environment
        @attributes = {}
        @values = {}
        @proxy = Proxy.new(evaluator: self)
      end

      def add_attribute(attribute)
        @attributes[attribute.name] = attribute
      end

      def add_attributes(attributes)
        attributes.each do |attribute|
          add_attribute(attribute)
        end
      end

      def add_values(values)
        @values.merge!(values)
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

      def evaluate(*arguments, &block)
        @proxy.instance_exec(*arguments, &block)
      end

      ruby2_keywords :evaluate

      def attribute?(name:)
        @attributes.key?(name)
      end
    end
  end
end
