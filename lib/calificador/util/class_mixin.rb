# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    # Patches for Class objects
    module ClassMixin
      sig { params(trait: T.nilable(Symbol)).returns(Key) }
      def with(trait)
        Key[T.cast(self, Module), trait]
      end

      alias_method :+, :with
    end
  end
end
