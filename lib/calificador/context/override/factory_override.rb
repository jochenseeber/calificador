# frozen_string_literal: true

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
          key = @key.with_default(context.subject_key)
          factory = context.override_factory(key: key)
          factory.init_with = @function
        end
      end
    end
  end
end
