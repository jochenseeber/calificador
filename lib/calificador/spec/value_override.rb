# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Spec
    # Factory calss
    class ValueOverride
      attr_reader :key, :values

      def initialize(key:, values: {})
        @key = key
        @values = values.dup.freeze
      end

      def merge(other)
        raise(ArgumentError, "Overrides must have same key") if @key != other.key

        if other.values.empty? || equal?(other)
          self
        elsif @values.empty?
          other
        else
          ValueOverride.new(key: @key, values: @values.merge(other.values))
        end
      end

      def merge_values(values)
        if values.empty?
          self
        else
          ValueOverride.new(key: @key, values: @values.merge(values))
        end
      end
    end
  end
end
