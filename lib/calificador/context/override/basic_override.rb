# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    module Override
      # Base class for overrides
      class BasicOverride
        abstract!

        sig { abstract.params(context: BasicContext).void }
        def apply(context:); end
      end
    end
  end
end
