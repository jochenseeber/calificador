# frozen_string_literal: true

require "calificador/util/core_extensions"
require "minitest"
require "pathname"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

# Main module
module Calificador
  MISSING = Util::Missing.instance

  BASE_DIR = Pathname(__FILE__).expand_path.dirname

  METHOD_PATTERN = %r{[[:alpha:]](?:[[:alnum:]]|_)*}.freeze

  class << self
    attr_writer :call_formatter

    def call_formatter
      @call_formatter ||= Calificador::Util::CallFormatter.new
    end
  end

  def self.test(subject_type, trait: Key::INHERITED_TRAIT, &block)
    raise "Subject type must be a #{Module}" unless subject_type.is_a?(Module)

    test_class = Class.new(Calificador::Test)
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

Class.include(Calificador::Util::ClassMixin)
Minitest::Assertion.prepend(Calificador::Minitest::MinitestPatches::AssertionMethods)
