# frozen_string_literal: true

require "singleton"

module Calificador
  module Util
    # Wrapper for nil values
    class Nil
      module ObjectMixin
        def unmask_nil
          self
        end

        def mask_nil
          self
        end
      end

      Object.include(ObjectMixin)

      module NilClassMixin
        def mask_nil
          Nil.instance
        end
      end

      NilClass.include(NilClassMixin)

      include Singleton

      def initialize
        freeze
      end

      def self.[](value)
        case value
        when nil, Nil.instance
          Nil.instance
        else
          value
        end
      end

      def unmask_nil
        nil
      end

      def mask_nil
        self
      end

      def to_s
        "<nil>"
      end

      alias_method :inspect, :to_s
    end
  end
end
