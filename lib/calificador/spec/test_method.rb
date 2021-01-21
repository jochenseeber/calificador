# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    # Factory class
    class TestMethod < BasicContext
      class Dsl < BasicContext::Dsl
        def body(&block)
          delegate.body = block
        end
      end

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
            __run_test(test_method: test_method)
          end
        METHOD

        super
      end

      def method_name
        @method_name ||= "test_: #{full_description}"
      end

      def run_test(test:)
        body = self.body
        environment = TestEnvironment.new(test: test, context: self)

        if expected_to_fail
          passed = begin
            environment.instance_exec(&body)
            true
          rescue ::Minitest::Assertion => e
            test.pass(e.message)
            false
          end

          test.flunk("Expected test to fail") if passed
        else
          environment.instance_exec(&body)
        end

        environment.__done
      end
    end
  end
end
