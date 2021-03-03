# frozen_string_literal: true

require "calificador"

module Calificador
  module Assert
    def assert(&block)
      Calificador::Assertor.new(block: block)
    end

    def refute(&block)
      Calificador::Assertor.new(negated: true, block: block)
    end
  end
end
