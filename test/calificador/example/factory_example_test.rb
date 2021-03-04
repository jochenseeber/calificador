# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Example
    FactoryExample = Struct.new(:init, :property, :after, keyword_init: true) do
      class << self
        attr_accessor :before
      end
    end

    class FactoryExampleTest < Calificador::Test
      factory FactoryExample do
        property { :main }

        transient do
          before { nil }
          after { nil }
        end

        before_create do
          FactoryExample.before = :main
        end

        after_create do |object|
          object.after = :main
        end

        init_with do
          FactoryExample.new(init: :main)
        end

        trait :trait do
          property { :trait }

          before_create do
            FactoryExample.before = :trait
          end

          after_create do |object|
            object.after = :trait
          end

          init_with do
            FactoryExample.new(init: :trait)
          end
        end
      end

      must "create subject with main factory" do
        assert { subject.property } == :main

        assert { subject.init } == :main
        assert { subject.after } == :main
        assert { FactoryExample.before } == :main
      end

      must "create subject only once" do
        created_object = subject
        assert { subject.equal?(created_object) } == true
      end

      must "prefer trait over property", :trait do
        assert { subject.property } == :trait

        assert { subject.init } == :trait
        assert { subject.after } == :trait
        assert { FactoryExample.before } == :trait
      end

      must "prefer value over property", props { property { :something } } do
        assert { subject.property } == :something

        assert { subject.init } == :main
        assert { subject.after } == :main
        assert { FactoryExample.before } == :main
      end

      must "prefer value over trait and property", :trait, props { property { :something } } do
        assert { subject.property } == :something

        assert { subject.init } == :trait
        assert { subject.after } == :trait
        assert { FactoryExample.before } == :trait
      end

      with "trait", :trait do
        must "prefer trait over property" do
          assert { subject.property } == :trait

          assert { subject.init } == :trait
          assert { subject.after } == :trait
          assert { FactoryExample.before } == :trait
        end
      end

      with "value", props { property { :something } } do
        must "prefer value over property" do
          assert { subject.property } == :something

          assert { subject.init } == :main
          assert { subject.after } == :main
          assert { FactoryExample.before } == :main
        end
      end

      with "trait and value", :trait, props { property { :something } } do
        must "prefer value over trait and property" do
          assert { subject.property } == :something

          assert { subject.init } == :trait
          assert { subject.after } == :trait
          assert { FactoryExample.before } == :trait
        end
      end

      must "define factory methods" do
        assert { respond_to?(:factory_example) } == true
        assert { respond_to?(:factory_example_trait) } == true
      end

      must "create objects using factory methods" do
        assert { factory_example.property } == :main
        assert { factory_example_trait.property } == :trait
      end

      with "value for factory", props(FactoryExample) { property { :other } } do
        must "override factory" do
          assert { create(FactoryExample).property } == :other
        end
      end

      with "value for factory with trait",
           props { property { :override } },
           props(FactoryExample, :trait) { property { :other } } do
        must "override factory" do
          assert { create(FactoryExample).property } == :override
          assert { create(FactoryExample, :trait).property } == :other
        end
      end
    end
  end
end
