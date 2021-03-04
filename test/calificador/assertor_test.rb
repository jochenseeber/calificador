# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  class AssertorTest < Calificador::Test
    factory Assertor do
      transient do
        negated { false }
        block { -> { 1 } }
      end

      init_with do
        Assertor.new(handler: Assertor::DefaultHandler.instance, negated: negated, block: block)
      end
    end

    must "raise error if delegate does not unterstand method" do
      assert { subject.unknown }.raises?(NoMethodError)
    end

    must "respond if delegate understands method" do
      subject.respond_to?(:zero?)
    end

    must "not respond if delegate does not understand method" do
      assert { subject.respond_to?(:unknown) }.raises?(MiniTest::Assertion)
    end

    must "raise error if no block given", props { block { nil } } do
      assert { subject.true? }.raises?(StandardError)
    end

    operation :not do
      must "negate assertor" do
        subject.not
        #  == 2
        # assert { subject.not.instance_eval { @negated } } == true
      end
    end

    operation :identical? do
      one = String.new("one")

      must "pass if identical", props { block { -> { one } } } do
        subject.identical?(one)
      end

      must "flunk if not identical", props { block { -> { one } } } do
        assert { subject.identical?(String.new("one")) }.raises?(MiniTest::Assertion)
      end
    end

    operation :"==" do
      must "pass if equal" do
        subject == 1
      end

      must "flunk if not equal" do
        assert { subject == 99 }.raises?(MiniTest::Assertion)
      end
    end

    operation :"!=" do
      must "pass if not equal" do
        subject != 99
      end

      must "flunk if equal" do
        assert { subject != 1 }.raises?(MiniTest::Assertion)
      end
    end

    operation :raises? do
      must "pass if expected exception is thrown", props { block { -> { raise StandardError } } } do
        subject.raises?(StandardError)
      end

      must "flunk if no exception is thrown" do
        assert { subject.raises?(StandardError) }.raises?(MiniTest::Assertion)
      end

      must "flunk if other than expected exception is thrown", props { block { -> { raise StandardError } } } do
        assert { subject.raises?(KeyError) }.raises?(MiniTest::Assertion)
      end

      must "raise exception if exception list is empty" do
        assert { subject.raises? }.raises?(ArgumentError)
      end

      must "raise exception if no block given", props { block { nil } } do
        assert { subject.raises?(StandardError) }.raises?(ArgumentError)
      end

      must "pass through non StandardError exceptions", props { block { -> { raise SignalException, "HUP" } } } do
        assert { subject.raises?(StandardError) }.raises?(SignalException)
      end

      must "pass through MiniTest Assertion exception", props { block { -> { raise MiniTest::Assertion } } } do
        assert { subject.raises?(StandardError) }.raises?(MiniTest::Assertion)
      end
    end

    with "proxied method" do
      must "pass if true" do
        subject.positive?
      end

      must "flunk if false" do
        assert { subject.zero? }.raises?(MiniTest::Assertion)
      end
    end

    where "negated", props { negated { true } } do
      operation :"==" do
        must "flunk if equal" do
          assert { subject == 1 }.raises?(MiniTest::Assertion)
        end

        must "pass if not equal" do
          subject == 99
        end
      end

      operation :"!=" do
        must "pass if equal" do
          subject != 1
        end

        must "pass if not equal" do
          assert { subject != 99 }.raises?(MiniTest::Assertion)
        end

        operation :identical? do
          one = -> { String.new("one") }

          must "flunk if identical", props { block { one } } do
            assert { subject.identical?(one) }.raises?(MiniTest::Assertion)
          end

          must "pass if not identical", props { block { one } } do
            subject.identical?(String.new("one"))
          end
        end

        with "proxied method" do
          must "flunk if true" do
            assert { subject.positive? }.raises?(MiniTest::Assertion)
          end

          must "pass if false" do
            subject.zero?
          end
        end
      end

      must "flunk if expected exception is thrown", props { block { -> { raise StandardError } } } do
        assert { subject.raises?(StandardError) }.raises?(MiniTest::Assertion)
      end

      must "pass if no exception is thrown" do
        subject.raises?(StandardError)
      end

      must "pass if other than expected exception is thrown" do
        subject.raises?(KeyError)
      end
    end
  end
end
