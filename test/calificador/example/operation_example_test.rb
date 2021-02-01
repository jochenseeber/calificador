# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Example
    OperationExample = Struct.new(:string, :parts, keyword_init: true) do
      def split(separator:, limit: -1)
        self.parts = string.split(separator, limit)
      end
    end

    class OperationExampleTest < Calificador::Test
      factory OperationExample do
        init_with { OperationExample.new(string: "one, two, three") }
      end

      operation :split, args { separator { %r{\s*,\s*} } } do
        must "split all parts when no limit is set" do
          assert { split(separator: _, limit: -1) } == %w[one two three]
        end

        must "respect limit when splitting" do
          assert { split(separator: _, limit: 2) } == ["one", "two, three"]
        end
      end

      examine String, -> { "one, two, three" } do
        operation :split, args { separator[0] { %r{\s*,\s*} } } do
          must "split all parts when no limit is set" do
            assert { split(_) } == %w[one two three]
          end

          must "respect limit when splitting" do
            assert { split(_, 2) } == ["one", "two, three"]
          end
        end
      end
    end
  end
end
