# frozen_string_literal: true

require "test_base"

module Calificador
  class KeyTest < Calificador::Test
    KeyExample = Struct.new(:tested, keyword_init: true)

    factory Key do
      transient do
        type { KeyExample }
        trait_name { Key::DEFAULT_TRAIT }
      end

      init_with do
        Key.new(type: type, trait: trait_name)
      end
    end

    class_method :new do
      must "raise error if inherited trait given" do
        arguments type: KeyExample, trait: Key::INHERITED_TRAIT
        assert.raises?(ArgumentError)
      end
    end

    class_method :"[]" do
      must "create key without trait" do
        arguments KeyExample
        assert == Key[KeyExample]
      end

      must "create key with trait" do
        arguments KeyExample, :test
        assert == Key[KeyExample, :test]
      end
    end

    method :with do
      must "return key with trait for key without trait", trait_name: nil do
        arguments :variant
        assert == Key[KeyExample, :variant]
      end

      must "return key with trait for key with trait", trait_name: :variant do
        arguments :variant
        assert == Key[KeyExample, :variant]
      end

      must "return key without trait for key without trait", trait_name: nil do
        arguments nil
        assert == Key[KeyExample]
      end

      must "return key without trait for key with trait", trait_name: :variant do
        arguments nil
        assert == Key[KeyExample]
      end
    end

    method :"==" do
      must "return true for keys with same type" do
        arguments Key[KeyExample]
        assert == true
      end

      must "return true for keys with same type and trait", trait_name: :test do
        arguments Key[KeyExample, :test]
        assert == true
      end

      must "return false for keys with different type" do
        arguments Key[String]
        assert == false
      end

      must "return false for keys with different traits", trait_name: :test do
        arguments Key[KeyExample, :other]
        assert == false
      end
    end

    method :hash do
      must "return same value for keys with same type" do
        assert == Key[KeyExample].hash
      end

      must "return same value for keys with same type and trait", trait_name: :test do
        assert == Key[KeyExample, :test].hash
      end
    end

    method :to_s do
      must "return type for keys without trait" do
        assert { subject.to_s } == KeyExample.name
      end

      must "return type and trait for keys with trait", trait_name: :test do
        assert { subject.to_s } == "#{KeyExample.name} (test)"
      end
    end
  end
end
