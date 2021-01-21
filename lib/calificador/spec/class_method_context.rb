# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    # Context that describes an instance method
    class ClassMethodContext < BasicContext
      class Dsl < BasicContext::Dsl
      end

      attr_reader :method

      def initialize(parent:, method:, description: nil)
        super(
          parent: parent,
          subject_key: parent.subject_key,
          description: description,
          overrides: {}
        )

        @method = method
      end

      def separate_description_by_space?
        @parent && !@parent.is_a?(ExamineContext)
      end

      def create_subject(environment:, subject_key:)
        subject_key.type
      end

      def create_result(subject:, arguments:, options:, block:)
        if options.empty?
          subject.send(@method, *arguments, &block)
        else
          subject.send(@method, *arguments, **options, &block)
        end
      end
    end
  end
end
