# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    module Override
      # Factory override
      class FactoryOverride < BasicOverride
        sig { returns(Key) }
        attr_reader :key

        sig { returns(InitProc) }
        attr_reader :function

        sig { params(key: Key, function: InitProc).void }
        def initialize(key:, function:)
          super()

          @key = key
          @function = function
        end

        sig { override.params(context: BasicContext).void }
        def apply(context:)
          key = @key.with_default(context.subject_key)
          factory = context.override_factory(key: key)
          factory.init_with = @function
        end
      end
    end
  end
end
