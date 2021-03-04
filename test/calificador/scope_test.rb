# typed: false
# frozen_string_literal: true

require "calificador/test_base"

class ScopeTest < Calificador::Test
  examines Object

  def root_method
    true
  end

  root_variable = true

  where "inside test method" do
    parent_variable = true

    must "be able to access Kernel method" do
      x = caller
      refute { x }.nil?
    end

    must "be able to access root method" do
      x = root_method
      assert { x } == true
    end

    must "be able to access environment method" do
      x = subject
      assert { x.is_a?(Object) } == true
    end

    must "be able to access root variable" do
      x = root_variable
      assert { x } == true
    end

    must "be able to access parent variable" do
      x = parent_variable
      assert { x } == true
    end

    must "raise error if method added" do
      assert.raises?(RuntimeError) do
        Class.new(Calificador::Test) do
          examines Object
          where "something" do
            def illegal_method_definition_inside_context; end
            puts instance_methods.sort.to_s
            puts singleton_methods.sort.to_s
          end
        end
      end
    end
  end

  where "inside assertion" do
    parent_variable = true

    must "be able to access Kernel method" do
      refute { caller }.nil?
    end

    must "be able to access root method" do
      assert { root_method } == true
    end

    must "be able to access environment method" do
      assert { subject.is_a?(Object) } == true
    end

    must "be able to access root variable" do
      assert { root_variable } == true
    end

    must "be able to access parent variable" do
      assert { parent_variable } == true
    end

    must "be able to access local variable" do
      local_variable = true
      assert { local_variable } == true
    end

    must "be able to set local variable" do
      local_variable = false

      assert { local_variable = true } == true
      assert { local_variable } == true
    end

    must "raise error if method added" do
      assert { def illegal_method_definition_inside_assert; end }.raises?(RuntimeError)
    end
  end

  ScopeDummy = Struct.new(:result, keyword_init: true)

  factory ScopeDummy do
    trait :root_method do
      result { root_method }
    end

    trait :root_variable do
      result { root_variable }
    end
  end

  examine ScopeDummy do
    where "inside factory definition" do
      must "be able to access root method", :root_method do
        assert { subject.result } == true
      end

      must "be able to access root variable", :root_variable do
        assert { subject.result } == true
      end

      must "raise error if method added" do
        assert.raises?(RuntimeError) do
          Class.new(Calificador::Test) do
            examines Object
            factory Object do
              def illegal_method_definition_inside_factory; end
              init_with { Object.new }
            end
          end
        end
      end
    end
  end
end
