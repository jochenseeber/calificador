# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    # Context that describes an instance method
    class OperationContext < BasicContext
      sig { returns(Symbol) }
      attr_reader :operation_name

      sig do
        params(
          parent: T.nilable(BasicContext),
          subject_key: Key,
          name: Symbol,
          description: String,
          overrides: T::Array[Override::BasicOverride]
        ).void
      end
      def initialize(parent:, subject_key:, name:, description:, overrides: [])
        super(
          parent: parent,
          subject_key: subject_key,
          description: description,
          overrides: overrides,
        )

        @operation_name = name
      end

      sig { returns(T::Boolean) }
      def separate_description_by_space?
        parent = self.parent
        parent && !parent.is_a?(InstanceContext) && !parent.is_a?(TypeContext) ? true : false
      end
    end
  end
end
