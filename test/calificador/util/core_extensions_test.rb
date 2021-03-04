# typed: false
# frozen_string_literal: true

require "calificador/test_base"

module Calificador
  module Util
    class CoreExtensionsTest < Calificador::Test
      examine Proc do
        operation :map_call_arguments, args { arguments { [] }; keywords { {} } } do
          with "positional arguments", -> { ->(a, b = 2, c) {} } do
            must "omit excess arguments" do
              assert { map_call_arguments(arguments: [1, 2, 3, 4], keywords: _) } == [1, 2, 3]
            end

            must "omit excess arguments" do
              assert { map_call_arguments(arguments: [1, 2, 3, 4], keywords: _) } == [1, 2, 3]
            end

            must "raise error if argument is missing" do
              assert { map_call_arguments(arguments: [1], keywords: _) }.raises?(ArgumentError)
            end

            must "map optional argument if present" do
              assert { map_call_arguments(arguments: [1, 2, 3], keywords: _) } == [1, 2, 3]
            end

            must "omit optional argument if missing" do
              assert { map_call_arguments(arguments: [1, 2], keywords: _) } == [1, 2]
            end
          end

          with "splat", -> { ->(a, *b) {} } do
            must "map remaining arguments if present" do
              assert { map_call_arguments(arguments: [1, 2, 3], keywords: _) } == [1, 2, 3]
            end

            must "omit remaining arguments if missing" do
              assert { map_call_arguments(arguments: [1], keywords: _) } == [1]
            end
          end

          with "keyword arguments", -> { ->(a:, b: 2, c:) {} } do
            must "omit excess arguments" do
              assert do
                map_call_arguments(arguments: _, keywords: { a: 1, b: 2, c: 3, d: 4 })
              end == [{ a: 1, b: 2, c: 3 }]
            end

            must "raise error if arguments are missing" do
              assert { map_call_arguments(arguments: _, keywords: { a: 1, b: 2 }) }.raises?(ArgumentError)
            end

            must "map optional arguments if present" do
              assert do
                map_call_arguments(arguments: _, keywords: { a: 1, b: 2, c: 3 })
              end == [{ a: 1, b: 2, c: 3 }]
            end

            must "omit optional arguments if missing" do
              assert do
                map_call_arguments(arguments: _, keywords: { a: 1, c: 3 })
              end == [{ a: 1, c: 3 }]
            end
          end

          with "double splat", -> { ->(a:, **b) {} } do
            must "map remaining arguments if present" do
              assert do
                map_call_arguments(arguments: _, keywords: { a: 1, b: 2, c: 3 })
              end == [{ a: 1, b: 2, c: 3 }]
            end

            must "omit remaining arguments if missing" do
              assert { map_call_arguments(arguments: _, keywords: { a: 1 }) } == [{ a: 1 }]
            end
          end

          must "ignore block argument", -> { ->(a, &b) {} } do
            assert { map_call_arguments(arguments: [1], keywords: _) } == [1]
          end

          must "raise error on invalid signature", -> { ->(a) {} } do
            subject.define_singleton_method(:parameters) do
              [%i[invalid a]]
            end

            assert { map_call_arguments(arguments: _, keywords: _) }.raises?(ArgumentError)
          end
        end
      end

      examine String do
        operation :snake_case do
          must "convert camel to snake case" do
            assert { "DefaultHttpContext".snake_case } == "default_http_context"
          end
        end

        operation :camel_case do
          must "convert snake case to camel case" do
            assert { "default_http_context".camel_case } == "DefaultHttpContext"
            assert { "_default".camel_case } == "Default"
            assert { "default_".camel_case } == "Default_"
          end
        end
      end

      examine Object do
        operation :to_bool do
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

      factory Module do
        transient do
          name { nil }
        end

        init_with do
          m = Module.new

          unless name.nil?
            method_definition = <<~METHOD
              def self.name
                "#{name}"
              end
            METHOD

            m.instance_eval(method_definition, __FILE__, __LINE__ + 1)
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
        operation :parent_name do
          must "return parent module name", :nested do
            assert { parent_name } == "Calificador"
          end

          must "return nil if no parent module", :toplevel do
            assert { parent_name }.nil?
          end
        end

        operation :parent_prefix do
          must "return parent module name plus separator", :nested do
            assert { parent_prefix } == "Calificador::"
          end

          must "return empty string if no parent module", :toplevel do
            assert { parent_prefix } == ""
          end
        end

        operation :parent_module do
          must "return parent module", :nested do
            assert { parent_module } == Calificador
          end

          must "return nil for anonymous modules" do
            assert { parent_module }.nil?
          end

          must "return nil if module has no parent", :toplevel do
            assert { parent_module }.nil?
          end

          must "raise error if parent name cannot be parsed", :invalid do
            assert { parent_module }.raises?(NameError)
          end
        end

        operation :base_name do
          must "return base name", :nested do
            assert { base_name } == "NestedModule"
          end
        end
      end

      examine Array, -> { [1, 2, 3] } do
        operation :remove_common_prefix do
          where "arrays have common prefix" do
            must "return array without prefix when arrays have same length" do
              assert { remove_common_prefix([1, 2, 4]) } == [3]
            end

            must "return array without prefix when other array is longer" do
              assert { remove_common_prefix([1, 2, 4, 5]) } == [3]
            end

            must "return array without prefix when other array is smaller" do
              assert { remove_common_prefix([1, 2]) } == [3]
            end
          end

          must "return full array if there is no common prefix" do
            assert { remove_common_prefix([2, 1]) } == [1, 2, 3]
          end

          must "return empty array if arrays are equal" do
            assert { remove_common_prefix([1, 2, 3]) } == []
          end
        end
      end
    end
  end
end
