# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    module Override
      # Factory override
      class FactoryOverride < BasicOverride
        attr_reader :key, :function

        def initialize(key:, function:)
          raise ArgumentError, "Key must be a #{Key}, not '#{key}' (#{key.class})" unless key.is_a?(Key)

          unless function.is_a?(Proc)
            raise ArgumentError, "Function must be a #{Proc}, not '#{function}' (#{function.class})"
          end

          super()

          @key = key
          @function = function
        end

        def apply(context:)
          factory = context.override_factory(key: @key)
          factory.init_with = @function
        end

        def with_default(trait:)
          raise ArgumentError, "Trait must be a #{Symbol}" unless trait.is_a?(Symbol)
          
          if @key.default_trait? && trait != @key.trait
            self.class.new(key: @key.with(trait), function: @function)
          else
            self
          end
        end
      end
    end
  end
end
