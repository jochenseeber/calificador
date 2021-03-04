# typed: strict
# frozen_string_literal: true

require "singleton"

module Calificador
  module Build
    class AttributeEvaluator
      class Evaluating
        include Singleton

        sig { returns(String) }
        def to_s
          "<evaluating>"
        end

        alias_method :inspect, :to_s
      end

      EVALUATING = T.let(Evaluating.instance, Evaluating)

      # Proxy for block evaluation
      class Proxy < Util::OvertProxyObject
        sig { params(evaluator: AttributeEvaluator).void }
        def initialize(evaluator:)
          super()

          @evaluator = evaluator
          @environment_proxy = ::T.let(evaluator.environment.proxy, Context::TestEnvironment::Proxy)
        end

        protected

        sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
        def __respond_to_missing?(name:, include_all:)
          @evaluator.attribute?(name: name) || @environment_proxy.respond_to?(name)
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
          if @evaluator.attribute?(name: name)
            ::Kernel.raise ArgumentError, "Getter must not be called with arguments" unless arguments.empty?

            @evaluator.value(name: name)
          else
            ::T.unsafe(@environment_proxy).__send__(name, *arguments, &block)
          end
        end

        ruby2_keywords :__method_missing
      end

      sig { returns(T::Hash[Symbol, Attribute]) }
      attr_reader :attributes

      sig { returns(T::Hash[Symbol, BasicObject]) }
      attr_reader :values

      sig { returns(Context::TestEnvironment) }
      attr_reader :environment

      sig { params(key: Key, environment: Context::TestEnvironment).void }
      def initialize(key:, environment:)
        @key = key
        @environment = environment
        @attributes = T.let({}, T::Hash[Symbol, Attribute])
        @values = T.let({}, T::Hash[Symbol, BasicObject])
        @proxy = T.let(Proxy.new(evaluator: self), Proxy)
      end

      sig { params(attribute: Attribute).void }
      def add_attribute(attribute)
        @attributes[attribute.name] = attribute
      end

      sig { params(attributes: T::Enumerable[Attribute]).void }
      def add_attributes(attributes)
        attributes.each do |attribute|
          add_attribute(attribute)
        end
      end

      sig { params(values: T::Hash[Symbol, BasicObject]).void }
      def add_values(values)
        @values.merge!(values)
      end

      sig { params(name: Symbol).returns(BasicObject) }
      def value(name:)
        result = @values.fetch(name) do
          @values[name] = EVALUATING

          begin
            attribute = @attributes.fetch(name) do
              raise KeyError, "Could not find attribute '#{name}' for factory #{@key}"
            end

            @values[name] = evaluate(&attribute.config)
          rescue StandardError
            @values.delete(name)
            raise
          end
        end

        raise StandardError, "Endless recursion while evaluating attribute #{name}" if result == EVALUATING

        result
      end

      sig { params(arguments: BasicObject, block: Proc).returns(BasicObject) }
      def evaluate(*arguments, &block)
        T.unsafe(@proxy).instance_exec(*arguments, &block)
      end

      ruby2_keywords :evaluate

      sig { params(name: Symbol).returns(T::Boolean) }
      def attribute?(name:)
        @attributes.key?(name)
      end
    end
  end
end
