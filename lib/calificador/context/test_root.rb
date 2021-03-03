# frozen_string_literal: true

module Calificador
  module Context
    class TestRoot < InstanceContext
      attr_accessor :test_class

      def initialize(test_class:, subject_key:, description:, &body)
        super(parent: nil, subject_key: subject_key, description: description)

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

      protected

      def setup_body
        test_class.class_eval(&@body) if @body
      end
    end
  end
end
