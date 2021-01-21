# frozen_string_literal: true

require "stringio"
require "test_base"

using Calificador::Util::CoreExtensions

module Calificador
  module Util
    class CallFormatterTest < Calificador::Test
      User = Struct.new(:name, keyword_init: true) do
        def pretty_print(printer)
          printer.text("User(#{name})")
        end
      end

      method :value do
        must "format value" do
          arguments value: User.new(name: "john.doe")
          assert == "User(john.doe)"
        end
      end

      method :append_value do
        must "format value" do
          arguments value: User.new(name: "john.doe"), out: StringIO.new
          assert { result.string } == "User(john.doe)"
        end
      end

      method :method do
        must "format call" do
          arguments method: :run, arguments: [1, 2], options: { a: 3, b: 4 }
          assert == "run(1, 2, a: 3, b: 4)"
        end

        must "format call without arguments" do
          arguments method: :run, arguments: [], options: {}
          assert == "run"
        end

        must "format call with only positional arguments" do
          arguments method: :run, arguments: [1, 2], options: {}
          assert == "run(1, 2)"
        end

        must "format call with only keyword arguments" do
          arguments method: :run, arguments: [], options: { a: 3, b: 4 }
          assert == "run(a: 3, b: 4)"
        end
      end
    end
  end
end
