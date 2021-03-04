# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Example
  AssertExample = Struct.new(:name, :tested, keyword_init: true) do
    def complain
      raise SomeError, "Bark!"
    end
  end

  class SomeError < StandardError
  end

  class AssertExampleTest < Calificador::Test
    factory AssertExample do
      name { "john.doe" }
      tested { true }

      trait :untested do
        tested { false }
      end
    end

    must "set user" do
      subject.name = "john.doe"
      assert { subject.name } == "john.doe"
    end

    must "assert equality for equal values" do
      assert { subject.name } == "john.doe"
    end

    must "assert unequality for not equal values" do
      assert { subject.name } != "grinch"
    end

    must "override properties", props { tested { false } } do
      assert { subject.tested } == false
    end

    must_fail "if asserted exception is not raised" do
      assert { subject.tested }.raises?(StandardError)
    end

    must "pass if asserted exception is raised" do
      assert { subject.complain }.raises?(SomeError)
    end

    must_fail "if refuted exception is raised" do
      refute { subject.complain }.raises?(SomeError)
    end

    must_fail "if other than asserted exception is raised" do
      assert { subject.complain }.raises?(KeyError)
    end

    must "pass if other than refuted exception is raised" do
      refute { subject.complain }.raises?(KeyError)
    end
  end
end
end