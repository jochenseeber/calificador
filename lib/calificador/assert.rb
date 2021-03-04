# typed: strict
# frozen_string_literal: true

require "calificador"

module Calificador
  module Assert
    sig { params(block: T.proc.returns(Object)).returns(Calificador::Assertor) }
    def assert(&block)
      Calificador::Assertor.new(block: block)
    end

    sig { params(block: T.proc.returns(Object)).returns(Calificador::Assertor) }
    def refute(&block)
      Calificador::Assertor.new(negated: true, block: block)
    end
  end
end
