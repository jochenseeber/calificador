# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    module Override
      # Property override
      class PropertyOverride < BasicOverride
        # Configuration proxy to configure overrides
        class ConfigProxy < Util::OvertProxyObject
          sig { params(override: PropertyOverride).void }
          def initialize(override:)
            super()

            @override = ::T.let(override, PropertyOverride)
          end

          protected

          sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
          def __respond_to_missing?(name:, include_all:)
            METHOD_PATTERN =~ name.to_s ? true : false
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
            if METHOD_PATTERN =~ name.to_s
              ::Kernel.raise ::ArgumentError, "Property method '#{name}' cannot have arguments" unless arguments.empty?

              unless block
                ::Kernel.raise ::ArgumentError, "Property method '#{name}' must have a block for the property value"
              end

              @override.add_attribute(name: name, value: ::T.cast(block, InitProc))
            else
              super
            end
          end
        end

        sig { returns(Key) }
        attr_reader :key

        sig { returns(PropertyHash) }
        attr_reader :attributes

        sig { params(key: Key, attributes: PropertyHash).void }
        def initialize(key:, attributes: {})
          super()

          @key = key
          @attributes = T.let(attributes.dup, PropertyHash)
        end

        sig { params(name: Symbol, value: InitProc).void }
        def add_attribute(name:, value:)
          @attributes[name] = value
        end

        sig { params(block: T.proc.void).returns(T.self_type) }
        def config(&block)
          T.unsafe(ConfigProxy.new(override: self)).instance_exec(&block)
          self
        end

        sig { override.params(context: BasicContext).void }
        def apply(context:)
          key = @key.with_default(context.subject_key)
          factory = context.override_factory(key: key)
          factory.add_overrides(attributes)
        end
      end
    end
  end
end
