# frozen_string_literal: true

require "test_base"

module Calificador
  module Util
    class MissingTest < Calificador::Test
      factory Missing do
        # Create a separate "singleton" instance for testing because the real instance is used
        # internally as placeholder for missing parameters
        init_with { Missing.instance_eval { new } }
      end

      must "be singleton" do
        assert.raises?(NoMethodError) do
          Missing.new
        end
      end

      must "be frozen" do
        assert.frozen?
      end

      method :mask_nil do
        must "return Nil object" do
          assert.identical?(Nil.instance)
        end
      end

      method :to_s do
        must "must return '<missing>'" do
          assert == "<missing>"
        end
      end
    end
  end
end
