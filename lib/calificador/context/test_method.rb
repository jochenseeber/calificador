# typed: strict
# frozen_string_literal: true

module Calificador
  module Context
    # Factory class
    class TestMethod < BasicContext
      sig { returns(T.proc.void) }
      attr_reader :body

      sig { returns(T::Boolean) }
      attr_reader :expected_to_fail

      sig do
        params(
          parent: T.nilable(BasicContext),
          subject_key: Key,
          description: String,
          overrides: T::Array[Override::BasicOverride],
          expected_to_fail: T::Boolean,
          body: T.proc.void
        ).void
      end
      def initialize(parent:, subject_key:, description:, overrides:, expected_to_fail:, body:)
        super(parent: parent, subject_key: subject_key, description: description, overrides: overrides)

        @body = body
        @expected_to_fail = expected_to_fail
        @method_name = T.let(nil, T.nilable(Symbol))
      end

      sig { void }
      def setup
        super

        test_method = self # rubocop:disable Lint/UselessAssignment
        test_method_name = method_name # rubocop:disable Lint/UselessAssignment
        file, line_number = @body.source_location

        test_class.class_eval(<<~METHOD, file, line_number) # rubocop:disable Style/EvalWithLocation
          define_method(test_method_name) do
            __run_test(context: test_method)
          end
        METHOD
      end

      sig { returns(Symbol) }
      def method_name
        @method_name ||= :"test_: #{full_description}"
      end
    end
  end
end
