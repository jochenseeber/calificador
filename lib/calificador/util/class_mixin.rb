# frozen_string_literal: true

module Calificador
  module Util
    # Patches for Class objects
    module ClassMixin
      def with(trait)
        Key[self, trait]
      end

      alias + with
    end
  end
end
