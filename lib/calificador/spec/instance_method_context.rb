# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    # Context that describes an instance method
    class InstanceMethodContext < BasicContext
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

      def create_result(subject:, arguments:, options:, block:)
        if options.empty?
          subject.send(@method, *arguments, &block)
        else
          subject.send(@method, *arguments, **options, &block)
        end
      end

      def separate_description_by_space?
        @parent && !@parent.is_a?(ExamineContext)
      end
    end
  end
end
