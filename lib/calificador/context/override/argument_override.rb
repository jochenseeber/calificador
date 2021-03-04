# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    module Override
      # Argument override
      class ArgumentOverride < BasicOverride
        # Configuration proxy to configure overrides
        class ConfigProxy < Util::OvertProxyObject
          sig { params(override: Override::ArgumentOverride).void }
          def initialize(override:)
            super()

            @override = override
          end

          protected

          sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
          def __respond_to_missing?(name:, include_all:)
            METHOD_PATTERN =~ name.to_s || super
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
              name = name.to_sym

            if METHOD_PATTERN =~ name.to_s
              ::Kernel.raise ::ArgumentError, "Property method '#{name}' cannot have arguments" unless arguments.empty?

              @override.add_attribute(name: name, value: ::T.cast(block, InitProc)) if block

              ArgumentProxy.new(override: @override, name: name)
            else
              super
            end
          end

          ruby2_keywords :__method_missing
        end

        class ArgumentProxy < Util::OvertProxyObject
          sig { params(override: ArgumentOverride, name: ::Symbol).void }
          def initialize(override:, name:)
            super()

            @override = override
            @name = name
          end

          sig { params(index: ::Integer, block: InitProc).void }
          def [](index, &block)
            @override.add_attribute(name: index, value: block)
          end
        end

        sig { returns(ArgumentHash)}
        attr_reader :attributes

        sig { params(attributes: ArgumentHash).void }
        def initialize(attributes: {})
          super()

          @attributes = T.let(attributes.dup, ArgumentHash)
        end

        sig { params(name: T.any(Symbol, Integer), value: InitProc).void }
        def add_attribute(name:, value:)
          @attributes[name] = value
        end

        sig { params(block: T.proc.void).returns(T.self_type) }
        def config(&block)
          ConfigProxy.new(override: self).instance_exec(&T.unsafe(block))
          self
        end

        sig { override.params(context: BasicContext).void }
        def apply(context:)
          context.merge_operation_arguments(@attributes)
        end
      end
    end
  end
end
