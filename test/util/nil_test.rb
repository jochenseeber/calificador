# frozen_string_literal: true

require "test_base"

using Calificador::Util::CoreExtensions

module Calificador
  module Util
    class NilTest < Calificador::Test
      factory Nil do
        init_with { Nil.instance }
      end

      factory NilClass do
        init_with { nil }
      end

      must "be frozen" do
        assert.frozen?
      end

      must "be singleton" do
        assert == Nil.instance

        assert.raises?(NoMethodError) do
          Nil.new
        end
      end

      method :mask_nil do
        must "return self" do
          assert.identical?(Nil.instance)
        end
      end

      method :unmask_nil do
        must "return nil" do
          assert.nil?
        end
      end

      method :to_s do
        must "must return '<nil>'" do
          assert == "<nil>"
        end
      end

      examine Object do
        method :unmask_nil do
          must "return self" do
            assert.identical?(subject)
          end
        end

        method :mask_nil do
          must "return self" do
            assert.identical?(subject)
          end
        end
      end

      examine NilClass do
        method :mask_nil do
          must "return Nil singleton" do
            assert.identical?(Nil.instance)
          end
        end
      end
    end
  end
end
