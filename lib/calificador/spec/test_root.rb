# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    class TestRoot < ExamineContext
      class Dsl < ExamineContext::Dsl
        def body(&block)
          delegate.body = block
        end
      end

      attr_accessor :test_class

      def initialize(test_class:, subject_key:, description:, &body)
        super(parent: nil, subject_key: subject_key, description: description, overrides: {})

        @test_class = test_class
        @body = body
      end

      def body=(&block)
        test_class.class_eval(&block)
      end

      def setup
        setup_body

        super
      end

      def create_result(subject:, arguments:, options:, block:)
        subject
      end

      protected

      def setup_body
        test_class.class_eval(&@body) if @body
      end
    end
  end
end
