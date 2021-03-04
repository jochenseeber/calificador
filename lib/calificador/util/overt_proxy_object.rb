# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    # Proxy that is overt about its type
    class OvertProxyObject < ProxyObject
      sig { returns(::Class) }
      def class
        EscapeHatch.unchecked_class_of(self, try_without_method_calls: true)
      end

      sig { params(type: ::Module).returns(::T::Boolean) }
      def is_a?(type)
        self.class <= type ? true : false # rubocop:disable Style/RedundantConditional
      end
    end
  end
end
