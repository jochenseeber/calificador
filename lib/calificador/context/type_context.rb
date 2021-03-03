# frozen_string_literal: true

module Calificador
  module Context
    class TypeContext < BasicContext
      def initialize(parent:, subject_key:, description:, overrides: [])
        raise ArgumentError, "Subject must be a must be a #{BasicObject}" unless subject_key.type <= BasicObject

        super(
          parent: parent,
          description: description,
          subject_key: subject_key,
          overrides: overrides
        )
      end

      def create_subject(environment:)
        subject_key.type
      end

      def subtree_root?
        true
      end
    end
  end
end
