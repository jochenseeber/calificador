# frozen_string_literal: true

require "calificador/test_base"

using Calificador::Util::CoreExtensions

module Calificador
  module Util
    class NilTest < Calificador::Test
      factory NilClass do
        init_with { nil }
      end

      must "be frozen" do
        assert { subject }.frozen?
      end

      must "be singleton" do
        assert { subject }.identical?(Nil.instance)
      end

      type do
        must "not respond to new" do
          assert { subject.respond_to?(:new) } == false
        end
      end

      operation :mask_nil do
        must "return self" do
          assert { mask_nil }.identical?(Nil.instance)
        end
      end

      operation :unmask_nil do
        must "return nil" do
          assert { unmask_nil }.nil?
        end
      end

      operation :to_s do
        must "must return '<nil>'" do
          assert { to_s } == "<nil>"
        end
      end

      examine Object do
        operation :mask_nil do
          must "return self" do
            assert { mask_nil }.identical?(subject)
          end
        end

        operation :unmask_nil do
          must "return self" do
            assert { unmask_nil }.identical?(subject)
          end
        end
      end

      examine NilClass do
        operation :mask_nil do
          must "return Nil singleton" do
            assert { mask_nil }.identical?(Nil.instance)
          end
        end

        operation :unmask_nil do
          must "return nil" do
            assert { unmask_nil }.nil?
          end
        end
      end
    end
  end
end
