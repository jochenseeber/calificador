# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    module Override
      # Property override
      class PropertyOverride < BasicOverride
        # Configuration proxy to configure overrides
        class ConfigProxy < Util::ProxyObject
          def initialize(override:)
            super()

            @override = override
          end

          protected

          def __respond_to_missing?(name:, include_all:)
            METHOD_PATTERN =~ name
          end

          def __method_missing(name:, arguments:, keywords:, block:)
            ::Kernel.raise ::ArgumentError, "Property method '#{name}' cannot have arguments" unless arguments.empty?

            unless block
              ::Kernel.raise ::ArgumentError, "Property method '#{name}' must have a block for the property value"
            end

            @override.add_attribute(name: name, value: block)
          end
        end

        attr_reader :key, :attributes

        def initialize(key:, attributes: {})
          raise ArgumentError, "Key must be a #{Key}, not '#{key}' (#{key.class})" unless key.is_a?(Key)

          super()

          @key = key
          @attributes = attributes.dup
        end

        def add_attribute(name:, value:)
          @attributes[name] = value
        end

        def config(&block)
          ConfigProxy.new(override: self).instance_exec(&block)
          self
        end

        def apply(context:)
          key = @key.with_default(context.subject_key)
          factory = context.override_factory(key: key)
          factory.add_overrides(attributes)
        end
      end
    end
  end
end
