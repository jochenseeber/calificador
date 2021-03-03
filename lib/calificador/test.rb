# frozen_string_literal: true

require "minitest"

module Calificador
  # Base class for unit tests
  class Test < ::Minitest::Test
    prepend TestMixin
  end
end
