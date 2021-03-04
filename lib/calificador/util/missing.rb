# typed: strict
# frozen_string_literal: true

require "singleton"

module Calificador
  module Util
    # Marker for missing parameters
    class Missing
      include Singleton

      sig { void }
      def initialize
        freeze
      end

      sig { returns(Nil) }
      def mask_nil
        Nil.instance
      end

      sig { returns(String) }
      def to_s
        "<missing>"
      end

      alias_method :inspect, :to_s
    end
  end
end
