# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Util
    class MissingTest < Calificador::Test
      factory Missing do
        # Create a separate "singleton" instance for testing because the real instance is used
        # internally as placeholder for missing parameters
        init_with { Missing.instance_eval { new } }
      end

      type do
        must "be singleton" do
          assert { subject.respond_to?(:new) } == false
        end
      end

      must "be frozen" do
        assert { subject }.frozen?
      end

      operation :mask_nil do
        must "return Nil object" do
          assert { mask_nil }.identical?(Nil.instance)
        end
      end

      operation :to_s do
        must "must return '<missing>'" do
          assert { to_s } == "<missing>"
        end
      end
    end
  end
end
