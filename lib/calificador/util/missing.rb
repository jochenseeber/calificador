# frozen_string_literal: true

require "singleton"

module Calificador
  module Util
    # Marker for missing parameters
    class Missing
      include Singleton

      def initialize
        freeze
      end

      def mask_nil
        Nil.instance
      end

      def to_s
        "<missing>"
      end

      alias_method :inspect, :to_s
    end
  end
end
