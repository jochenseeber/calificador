# frozen_string_literal: true

require "test_base"

using Calificador::Util::CoreExtensions

module Calificador
  module Util
    class CoreExtensionsTest < Calificador::Test
      examine CoreExtensions do
        class_method :map_call_arguments do
          must "omit excess positional invoke" do
            arguments signature: [%i[req a]], arguments: [1, 2], options: {}
            assert == [[1], {}]
          end

          must "raise error if positional argument is missing" do
            arguments signature: [%i[req a], %i[req b]], arguments: [1], options: {}
            assert.raises?(ArgumentError)
          end

          must "map optional positional invoke if present" do
            arguments signature: [%i[req a], %i[opt b], %i[req c]], arguments: [1, 2, 3, 4], options: {}
            assert == [[1, 2, 3], {}]
          end

          must "omit optional positional invoke if missing" do
            arguments signature: [%i[req a], %i[opt b], %i[req c]], arguments: [1, 2], options: {}
            assert == [[1, 2], {}]
          end

          must "map remaining positional invoke if present" do
            arguments signature: [%i[req a], %i[rest b]], arguments: [1, 2, 3], options: {}
            assert == [[1, 2, 3], {}]
          end

          must "omit remaining positional invoke if missing" do
            arguments signature: [%i[req a], %i[rest b]], arguments: [1], options: {}
            assert == [[1], {}]
          end

          must "omit excess keyword invoke" do
            arguments signature: [%i[keyreq a]], arguments: [], options: { a: 1, b: 2 }
            assert == [[], { a: 1 }]
          end

          must "raise error if keyword invoke are missing" do
            arguments signature: [%i[keyreq a], %i[keyreq b]], arguments: [], options: { a: 1 }
            assert.raises?(ArgumentError)
          end

          must "map optional keyword invoke if present" do
            arguments signature: [%i[keyreq a], %i[key b], %i[keyreq c]], arguments: [], options: { a: 1, b: 2, c: 3 }
            assert == [[], { a: 1, b: 2, c: 3 }]
          end

          must "omit optional keyword invoke if missing" do
            arguments signature: [%i[keyreq a], %i[key b], %i[keyreq c]], arguments: [], options: { a: 1, c: 3 }
            assert == [[], { a: 1, c: 3 }]
          end

          must "map remaining keyword invoke if present" do
            arguments signature: [%i[keyreq a], %i[key b], %i[keyrest c]], arguments: [], options: { a: 1, b: 2, c: 3 }
            assert == [[], { a: 1, b: 2, c: 3 }]
          end

          must "omit remaining keyword invoke if missing" do
            arguments signature: [%i[keyreq a], %i[keyrest b]], arguments: [], options: { a: 1 }
            assert == [[], { a: 1 }]
          end

          must "ignore block invoke" do
            arguments signature: [%i[req a], %i[block b]], arguments: [1], options: {}
            assert == [[1], {}]
          end

          must "raise error on invalid signature" do
            arguments signature: [%i[invalid a]], arguments: [1], options: {}
            assert.raises?(ArgumentError)
          end
        end
      end

      examine String do
        method :snake_case do
          must "convert camel to snake case" do
            assert { "DefaultHttpContext".snake_case } == "default_http_context"
          end
        end

        method :camel_case do
          must "convert snake case to camel case" do
            assert { "default_http_context".camel_case } == "DefaultHttpContext"
            assert { "_default".camel_case } == "Default"
            assert { "default_".camel_case } == "Default_"
          end
        end
      end

      examine Object do
        method :to_bool do
          must "return true for object" do
            assert { Object.new.to_bool } == true
          end

          must "return false for nil" do
            assert { nil.to_bool } == false
          end

          must "return false for false" do
            assert { false.to_bool } == false
          end
        end
      end

      class DslObject
        class Dsl
          def initialize(delegate:)
            @delegate = delegate
          end

          def name(value = nil)
            value.nil? ? @delegate.name : @delegate.name = value
          end
        end

        attr_accessor :name
      end

      examine DslObject do
        method :dsl_config do
          must "configure object with DSL" do
            arguments { name "test" }
            assert { result.name } == "test"
          end

          must "skip configuration when called without block" do
            arguments {}
            assert { result.name }.nil?
          end
        end
      end

      factory Module do
        transient do
          name { nil }
        end

        init_with do
          m = Module.new

          unless name.nil?
            method = <<~METHOD
              def self.name
                "#{name}"
              end
            METHOD

            m.instance_eval(method, __FILE__, __LINE__ + 1)
          end

          m
        end

        trait :toplevel do
          name { "TopLevelModule" }
        end

        trait :nested do
          name { "Calificador::NestedModule" }
        end

        trait :invalid do
          name { "Calificador:::TestModule" }
        end
      end

      examine Module do
        method :parent_name do
          must "return parent module name", trait: :nested do
            assert == "Calificador"
          end

          must "return nil if no parent module", trait: :toplevel do
            assert.nil?
          end
        end

        method :parent_prefix do
          must "return parent module name plus separator", trait: :nested do
            assert == "Calificador::"
          end

          must "return empty string if no parent module", trait: :toplevel do
            assert == ""
          end
        end

        method :parent_module do
          must "return parent module", trait: :nested do
            assert == Calificador
          end

          must "return nil for anonymous modules" do
            assert.nil?
          end

          must "return nil if module has no parent", trait: :toplevel do
            assert.nil?
          end

          must "raise error if parent name cannot be parsed", trait: :invalid do
            assert.raises?(NameError)
          end
        end

        method :base_name do
          must "return base name", trait: :nested do
            assert == "NestedModule"
          end

          must "return nil for anonymous modules" do
            assert.nil?
          end
        end
      end
    end
  end
end
