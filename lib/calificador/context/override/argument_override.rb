# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    module Override
      # Argument override
      class ArgumentOverride < BasicOverride
        # Configuration proxy to configure overrides
        class ConfigProxy < Util::ProxyObject
          def initialize(override:)
            super()

            @override = override
          end

          protected

          def __respond_to_missing?(name:, include_all:)
            METHOD_PATTERN =~ name || super
          end

          def __method_missing(name:, arguments:, keywords:, block:)
            name = name.to_sym

            if METHOD_PATTERN =~ name
              ::Kernel.raise ::ArgumentError, "Property method '#{name}' cannot have arguments" unless arguments.empty?

              @override.add_attribute(name: name, value: block) if block

              ArgumentProxy.new(override: @override, name: name)
            else
              super
            end
          end
        end

        class ArgumentProxy < Util::ProxyObject
          def initialize(override:, name:)
            super()

            @override = override
            @name = name
          end

          def [](index, &block)
            @override.add_attribute(name: index, value: block)
          end
        end

        attr_reader :attributes

        def initialize(attributes: {})
          super()

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
          context.merge_operation_arguments(@attributes)
        end
      end
    end
  end
end
