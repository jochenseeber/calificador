# frozen_string_literal: true

module Calificador
  module Context
    module Override
      # Base class for overrides
      class BasicOverride
        def apply(context:)
          raise NotImplementedError, "Subclasses must implement"
        end
      end
    end
  end
end
