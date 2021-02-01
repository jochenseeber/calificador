# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    class InstanceContext < BasicContext
      def initialize(parent:, subject_key:, description:, overrides: [])
        super(
          parent: parent,
          description: description,
          subject_key: subject_key,
          overrides: overrides,
        )
      end

      def create_subject(environment:)
        environment.create_object(key: environment.subject_key)
      end

      def subtree_root?
        true
      end
    end
  end
end
