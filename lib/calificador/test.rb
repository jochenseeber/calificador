# frozen_string_literal: true

require "minitest"

using Calificador::Util::CoreExtensions

module Calificador
  # Base class for unit tests
  class Test < ::Minitest::Test
    include TestMixin
  end
end
