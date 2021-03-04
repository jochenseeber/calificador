# typed: strict
# frozen_string_literal: true

module Calificador
  module Build
    # Attribute description
    class Attribute
      TYPES = T.let(%i[property transient init].freeze, T::Array[Symbol])

      sig { returns(Symbol) }
      attr_reader :name

      sig { returns(Symbol) }
      attr_reader :type

      sig { returns(T.proc.returns(BasicObject)) }
      attr_reader :config

      sig { params(name: Symbol, type: Symbol, config: T.proc.returns(BasicObject)).void }
      def initialize(name:, type:, config:)
        raise "Illegal property type #{type}. Valid types are #{TYPES.join(", ")}" unless TYPES.include?(type.to_sym)

        @name = T.let(name.to_sym, Symbol)
        @type = T.let(type.to_sym, Symbol)
        @config = config
      end
    end
  end
end
