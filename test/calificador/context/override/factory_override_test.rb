# frozen_string_literal: true

require "calificador/test_base"

using Calificador::Util::CoreExtensions

module Calificador
  module Context
    module Override
      # Test for FactoryOverride
      class FactoryOverrideTest < Calificador::Test
        type do
          operation :new do
            must "raise error if key is not a key" do
              assert { new(key: "test", function: -> { "test" }) }.raises?(ArgumentError)
            end

            must "raise error if function is not a proc" do
              assert { new(key: Key[String], function: "test") }.raises?(ArgumentError)
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
            mock.override_factory(key: Key[String]) >> object_factory
          end
        end

        operation :apply do
          must "override init proc of factory" do
            subject.apply(context: basic_context)
            assert { object_factory.init_with } == subject.function
          end
        end

        operation :with_default do
          must "raise error if trait argument is nil" do
            assert { with_default(trait: nil) }.raises?(ArgumentError)
          end

          must "raise error if trait argument is not a Symbol" do
            assert { with_default(trait: "test") }.raises?(ArgumentError)
          end

          where "key has no trait", :no_trait do
            must "not override trait" do
              assert { with_default(trait: Key::NO_TRAIT).key } == Key[String]
              assert { with_default(trait: Key::DEFAULT_TRAIT).key } == Key[String]
              assert { with_default(trait: :custom).key } == Key[String]
            end
          end

          where "key has default trait", :default_trait do
            must "override default trait" do
              assert { with_default(trait: Key::NO_TRAIT).key } == Key[String]
              assert { with_default(trait: Key::DEFAULT_TRAIT).key } == Key[String, Key::DEFAULT_TRAIT]
              assert { with_default(trait: :custom).key } == Key[String, :custom]
            end
          end

          where "key has custom trait", :custom_trait do
            must "not override trait" do
              assert { with_default(trait: Key::NO_TRAIT).key } == Key[String, :custom]
              assert { with_default(trait: Key::DEFAULT_TRAIT).key } == Key[String, :custom]
              assert { with_default(trait: :custom).key } == Key[String, :custom]
            end
          end
        end
      end
    end
  end
end
