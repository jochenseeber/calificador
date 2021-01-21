# frozen_string_literal: true

module Calificador
  module Build
    # Attribute description
    class Attribute
      TYPES = %i[property transient init].freeze

      attr_reader :name, :type, :config

      def initialize(name:, type:, config:)
        raise "Illegal property type #{type}. Valid types are #{TYPES.join(", ")}" unless TYPES.include?(type.to_sym)

        @name = name.to_sym
        @type = type.to_sym
        @config = config
      end
    end
  end
end
