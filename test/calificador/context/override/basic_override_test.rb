# frozen_string_literal: true

require "calificador/test_base"

using Calificador::Util::CoreExtensions

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

        operation :with_default do
          must "return self" do
            assert { with_default(trait: :test) }.identical?(subject)
            assert { with_default(trait: Key::NO_TRAIT) }.identical?(subject)
            assert { with_default(trait: Key::DEFAULT_TRAIT) }.identical?(subject)
          end

          must "raise error if trait is not a Symbol" do
            assert { with_default(trait: "bad") }.raises?(ArgumentError)
            assert { with_default(trait: nil) }.raises?(ArgumentError)
          end
        end
      end
    end
  end
end
