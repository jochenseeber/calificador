# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  class KeyTest < Calificador::Test
    KeyExample = Struct.new(:tested, keyword_init: true)

    factory Key do
      transient do
        type { KeyExample }
        trait_name { nil }
      end

      trait :with_trait do
        trait_name { :test }
      end

      init_with do
        Key.new(type: type, trait: trait_name)
      end
    end

    type Key do
      operation :new do
        must "raise error if type is not a Module" do
          assert { Key.new(type: :bad) }.raises?(TypeError)
        end

        must "raise error if trait is not a Symbol" do
          assert { Key.new(type: String, trait: "bad") }.raises?(TypeError)
        end
      end

      operation :"[]" do
        must "create key with default trait" do
          assert { Key[KeyExample] } == Key.new(type: KeyExample)
        end

        must "create key with custom trait" do
          assert { Key[KeyExample, :test] } == Key.new(type: KeyExample, trait: :test)
        end
      end
    end

    operation :with do
      where "key has no trait" do
        must "return self when override is nil" do
          assert { subject.with(nil) }.identical?(subject)
        end

        must "return key with new trait if override is set" do
          assert { subject.with(:override) } == Key[KeyExample, :override]
        end
      end

      where "key has trait", :with_trait do
        must "return self when override is nil" do
          assert { subject.with(nil) }.identical?(subject)
        end

        must "return self when override is same" do
          assert { subject.with(:test) }.identical?(subject)
        end

        must "return key with new trait if override is set" do
          assert { subject.with(:override) } == Key[KeyExample, :override]
        end
      end
    end

    operation :"==" do
      must "return true for keys with same type" do
        assert { subject } == Key[KeyExample]
      end

      must "return true for keys with same type and trait", :with_trait do
        assert { subject } == Key[KeyExample, :test]
      end

      must "return false for keys with different type" do
        refute { subject } == Key[String]
      end

      must "return false for keys with different traits", :with_trait do
        refute { subject } == Key[KeyExample, :other]
      end
    end

    operation :hash do
      must "return same value for keys with same type" do
        assert { subject.hash } == Key[KeyExample].hash
      end

      must "return same value for keys with same type and trait", :with_trait do
        assert { subject.hash } == Key[KeyExample, :test].hash
      end
    end

    operation :to_s do
      must "return type name for keys without trait" do
        assert { subject.to_s } == KeyExample.name
      end

      must "return type name and trait for keys with trait", :with_trait do
        assert { subject.to_s } == "#{KeyExample.name} (test)"
      end
    end
  end
end
