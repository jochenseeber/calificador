# frozen_string_literal: true

module Calificador
  module Build
    # Trait description
    class Trait < AttributeContainer
      # Configuration proxy for traits
      class Dsl < AttributeContainer::Dsl
      end

      attr_reader :name

      def initialize(parent:, name:, description: nil)
        super(parent: parent, description: description)

        @name = name.to_sym
      end
    end
  end
end
