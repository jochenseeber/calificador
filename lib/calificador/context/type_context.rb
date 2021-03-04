# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    class TypeContext < BasicContext
      sig do
        params(
          parent: T.nilable(BasicContext),
          subject_key: Key,
          description: String,
          overrides: T::Array[Override::BasicOverride]
        ).void
      end
      def initialize(parent:, subject_key:, description:, overrides:)
        raise ArgumentError, "Subject must be a must be a #{BasicObject}" unless subject_key.type <= BasicObject

        super(
          parent: parent,
          description: description,
          subject_key: subject_key,
          overrides: overrides
        )
      end

      sig { params(environment: TestEnvironment).returns(BasicObject) }
      def create_subject(environment:)
        subject_key.type
      end

      sig { returns(T::Boolean) }
      def subtree_root?
        true
      end
    end
  end
end
