# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    class TestRoot < InstanceContext
      sig { returns(TestClassType) }
      attr_accessor :test_class

      sig do
        params(
          test_class: TestClassType,
          subject_key: Key,
          description: String,
          body: T.nilable(InitProc)
        ).void
      end
      def initialize(test_class:, subject_key:, description:, &body)
        super(parent: nil, subject_key: subject_key, description: description)

        @test_class = test_class
        @body = body
      end

      sig { params(block: InitProc).void }
      def body=(&block)
        @body = block
      end

      sig { void }
      def setup
        setup_body

        super
      end

      protected

      sig { void }
      def setup_body
        T.unsafe(test_class).class_eval(&@body) if @body
      end
    end
  end
end
