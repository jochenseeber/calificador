# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Context
    module Override
      # Test for FactoryOverride
      class ArgumentOverrideTest < Calificador::Test
        type do
          operation :new do
            must "copy and set attributes" do
              config = -> { "test" }
              assert { new(attributes: { test: config }).attributes } == { test: config }
              refute { new(attributes: { test: config }).attributes }.identical?({ test: config })
            end
          end
        end

        operation :add_attribute do
          must "add attribute" do
            config =  -> { "test " }
            add_attribute(name: :test, value: config)
            assert { subject.attributes.fetch(:test) } == config
          end
        end
      end
    end
  end
end
