# frozen_string_literal: true

module Calificador
  module Context
    # Factory class
    class TestMethod < BasicContext
      attr_reader :body, :expected_to_fail

      def initialize(parent:, subject_key:, description:, overrides:, expected_to_fail: false, body:)
        super(parent: parent, subject_key: subject_key, description: description, overrides: overrides)

        @body = body
        @expected_to_fail = expected_to_fail
      end

      def setup
        test_method = self # rubocop:disable Lint/UselessAssignment
        test_method_name = method_name # rubocop:disable Lint/UselessAssignment
        file, line_number = @body.source_location

        test_class.class_eval(<<~METHOD, file, line_number)
          define_method(test_method_name) do
            __run_test(context: test_method)
          end
        METHOD

        super
      end

      def method_name
        @method_name ||= "test_: #{full_description}"
      end
    end
  end
end
