# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    class ExamineContext < BasicContext
      class Dsl < BasicContext::Dsl
      end

      def initialize(parent:, subject_key:, description:, overrides: {})
        super(
          parent: parent,
          description: description,
          subject_key: subject_key,
          overrides: overrides,
        )
      end

      def create_subject(environment:, subject_key:)
        environment.create_object(key: subject_key)
      end

      def subtree_root?
        true
      end
    end
  end
end
