# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Util
    class ClassMixinTest < Calificador::Test
      type String do
        operation :with do
          must "return key with trait" do
            assert { with(:test) } == Key[String, :test]
          end
        end
      end
    end
  end
end
