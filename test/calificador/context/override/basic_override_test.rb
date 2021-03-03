# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Context
    module Override
      # Test for BasicOverride
      class BasicOverrideTest < Calificador::Test
        operation :apply do
          must "raise unimplemented error" do
            assert { apply(context: nil) }.raises?(NotImplementedError)
          end
        end
      end
    end
  end
end
