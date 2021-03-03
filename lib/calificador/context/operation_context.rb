# frozen_string_literal: true

module Calificador
  module Context
    # Context that describes an instance method
    class OperationContext < BasicContext
      attr_reader :operation_name

      def initialize(parent:, subject_key:, name:, description: nil, overrides: [])
        raise ArgumentError, "Operation name must not be nil" if name.nil?

        super(
          parent: parent,
          subject_key: subject_key,
          description: description,
          overrides: overrides
        )

        @operation_name = name
      end

      def separate_description_by_space?
        @parent && !@parent.is_a?(InstanceContext) && !@parent.is_a?(TypeContext)
      end
    end
  end
end
