# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Context
    module Override
      # Test for FactoryOverride
      class FactoryOverrideTest < Calificador::Test
        type do
          operation :new do
            must "raise error if key is not a key" do
              assert { new(key: "test", function: -> { "test" }) }.raises?(TypeError)
            end

            must "raise error if function is not a proc" do
              assert { new(key: Key[String], function: "test") }.raises?(TypeError)
            end
          end
        end

        factory FactoryOverride do
          transient do
            key { Key[String] }
            function { -> { "test" } }
          end

          trait :no_trait do
            transient do
              key { Key[String, Key::NO_TRAIT] }
            end
          end

          trait :default_trait do
            transient do
              key { Key[String, Key::DEFAULT_TRAIT] }
            end
          end

          trait :custom_trait do
            transient do
              key { Key[String, :custom] }
            end
          end
        end

        factory Build::ObjectFactory do
          init_with do
            Struct.new(:init_with).new
          end
        end

        mock BasicContext do
          expect do
            mock.subject_key >> Key[String]
            mock.override_factory(key: Key[String]) >> object_factory
          end
        end

        operation :apply do
          must "override init proc of factory" do
            subject.apply(context: basic_context)
            assert { object_factory.init_with } == subject.function
          end
        end
      end
    end
  end
end
