# frozen_string_literal: true

require "test_base"

module Calificador
  module Util
    class ClassMixinTest < Calificador::Test
      examine String do
        class_method :with do
          must "return key with trait" do
            arguments :test
            assert == Key[String, :test]
          end
        end
      end
    end
  end
end
