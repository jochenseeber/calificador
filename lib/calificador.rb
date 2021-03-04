# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

Module.include(T::Sig)
Module.include(T::Helpers)

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

require "calificador/util/core_extensions"
require "minitest"
require "pathname"

# Main module
module Calificador
  MISSING = T.let(Util::Missing.instance, Calificador::Util::Missing)

  BASE_DIR = T.let(Pathname(__FILE__).expand_path.dirname, Pathname)

  METHOD_PATTERN = T.let(%r{[[:alpha:]](?:[[:alnum:]]|_)*}.freeze, Regexp)

  @call_formatter = T.let(Util::CallFormatter.new, Util::CallFormatter)

  ArgumentHash = T.type_alias { T::Hash[T.any(Symbol, Integer), InitProc] }
  PropertyHash = T.type_alias { T::Hash[Symbol, InitProc] }
  ArgumentArray = T.type_alias { T::Array[BasicObject] }
  InitProc = T.type_alias { T.proc.returns(::BasicObject) }
  KeywordHash = T.type_alias { T::Hash[Symbol, BasicObject] }
  TestClassType = T.type_alias { T.all(T.class_of(::Minitest::Test), TestMixin::ClassMethods) }
  TestType = T.type_alias { T.all(::Minitest::Test, TestMixin) }

  class << self
    sig { returns(Util::CallFormatter) }
    attr_accessor :call_formatter

    sig { params(subject_type: Module, trait: T.nilable(Symbol)).returns(T.class_of(Test)) }
    def test(subject_type, trait: nil, &block)
      test_class = T.cast(Class.new(Test), T.class_of(Test))

      test_class_name = "#{subject_type.base_name}Test"
      test_module = subject_type.parent_module

      if test_module
        test_module.const_set(test_class_name, test_class)
      else
        Kernel.const_set(test_class_name, test_class)
      end

      test_class.examines(subject_type, trait)
      test_class.class_eval(&block)

      test_class
    end
  end
end

Class.include(Calificador::Util::ClassMixin)
Minitest::Test.include(Calificador::Assertor::Handler)
Minitest::Assertion.prepend(Calificador::Minitest::MinitestPatches::AssertionMethods)
