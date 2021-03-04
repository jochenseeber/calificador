# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    # Base class for proxy objects
    class ProxyObject < BasicObject
      FALLBACK_METHODS = ::T.let(%i[to_s inspect].freeze, ::T::Array[::Symbol])

      sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
      def respond_to?(name, include_all = false) # rubocop:disable Style/OptionalBooleanParameter
        __class.public_instance_methods(true).include?(name) ||
          include_all && (
            __class.protected_instance_methods(true).include?(name) ||
            __class.private_instance_methods(true).include?(name)
          ) ||
          respond_to_missing?(name, include_all)
      end

      sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
      def respond_to_missing?(name, include_all)
        name.start_with?("__") ? false : __respond_to_missing?(name: name, include_all: include_all)
      end

      ::T::Sig::WithoutRuntime.sig do
        params(name: ::Symbol, arguments: ::BasicObject, block: ::T.nilable(::Proc)).returns(::BasicObject)
      end
      def method_missing(name, *arguments, &block)
        if name.start_with?("__")
          super
        else
          keywords = Helper.extract_keywords(arguments: arguments)
          __method_missing(name: name, arguments: arguments, keywords: keywords, block: block)
        end
      end

      ruby2_keywords :method_missing

      sig { returns(::Class) }
      def __class
        EscapeHatch.unchecked_class_of(self, try_without_method_calls: true)
      end

      sig { params(type: ::Module).returns(::T::Boolean) }
      def __is_a?(type)
        type <= __class ? true : false # rubocop:disable Style/RedundantConditional
      end

      sig { returns(::String) }
      def __to_s
        "#<#{__class}>"
      end

      sig { returns(::String) }
      def __inspect
        "#<#{__class}>"
      end

      protected

      sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
      def __respond_to_missing?(name:, include_all:)
        false
      end

      sig do
        params(
          name: ::Symbol,
          arguments: ArgumentArray,
          keywords: KeywordHash,
          block: ::T.nilable(::Proc)
        ).returns(::BasicObject)
      end
      def __method_missing(name:, arguments:, keywords:, block: nil)
        if ::Kernel.respond_to?(name)
          ::T.unsafe(::Kernel).__send__(name, *arguments, &block)
        elsif FALLBACK_METHODS.include?(name)
          ::T.unsafe(self).__send__(:"__#{name}", *arguments, &block)
        else
          ::Kernel.raise ::NoMethodError, "undefined name `#{name}' for #{__class}"
        end
      end

      ruby2_keywords :__method_missing
    end
  end
end
