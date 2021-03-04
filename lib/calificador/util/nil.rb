# typed: strict
# frozen_string_literal: true

require "singleton"

module Calificador
  module Util
    # Wrapper for nil values
    class Nil
      extend T::Generic
      include Singleton

      module ObjectMixin
        sig { returns(T.nilable(T.self_type)) }
        def unmask_nil
          self
        end

        sig { returns(T.any(T.self_type, Nil)) }
        def mask_nil
          self
        end
      end

      Object.include(ObjectMixin)

      module NilClassMixin
        sig { returns(Nil) }
        def mask_nil
          Nil.instance
        end
      end

      NilClass.include(NilClassMixin)

      sig { void }
      def initialize
        freeze
      end

      sig { type_parameters(:T).params(value: T.type_parameter(:T)).returns(T.any(T.type_parameter(:T), Nil)) }
      def self.[](value)
        case T.cast(value, BasicObject)
        when nil, Nil.instance
          Nil.instance
        else
          value
        end
      end

      sig { returns(NilClass) }
      def unmask_nil
        nil
      end

      sig { returns(Nil) }
      def mask_nil
        self
      end

      sig { returns(String) }
      def to_s
        "<nil>"
      end

      alias_method :inspect, :to_s
    end
  end
end
