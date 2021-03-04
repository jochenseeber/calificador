# typed: false
# frozen_string_literal: true

require "stringio"
require "calificador/test_base"

module Calificador
  module Util
    class CallFormatterTest < Calificador::Test
      PrettyString = String.new("string")

      def PrettyString.pretty_print(printer)
        printer.text("pretty #{self}")
      end

      operation :format_value do
        must "format value" do
          assert { format_value(value: PrettyString) } == "pretty string"
        end
      end

      operation :append_value do
        must "format value" do
          assert { append_value(value: PrettyString, out: StringIO.new).string } == "pretty string"
        end
      end

      operation :format_method, args { name { :run }; arguments { [] }; keywords { {} } } do
        must "format call" do
          assert { format_method(name: _, arguments: [1, 2], keywords: { a: 3, b: 4 }) } == "run(1, 2, a: 3, b: 4)"
        end

        must "format call without arguments" do
          assert { format_method(name: _, arguments: _, keywords: _) } == "run"
        end

        must "format call with only positional arguments" do
          assert { format_method(name: _, arguments: [1, 2], keywords: _) } == "run(1, 2)"
        end

        must "format call with only keyword arguments" do
          assert { format_method(name: _, arguments: _, keywords: { a: 3, b: 4 }) } == "run(a: 3, b: 4)"
        end
      end
    end
  end
end
