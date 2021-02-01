# frozen_string_literal: true

module Calificador
  module Util
    # Base class for proxy objects
    class ProxyObject < BasicObject
      FALLBACK_METHODS = %i[class to_s inspect eval].freeze

      def respond_to?(name, include_all = false) # rubocop:disable Style/OptionalBooleanParameter
        __class.public_instance_methods(true).include?(name) ||
          include_all && (
            __class.protected_instance_methods(true).include?(name) ||
            __class.private_instance_methods(true).include?(name)
          ) ||
          respond_to_missing?(name, include_all)
      end

      def respond_to_missing?(name, include_all)
        name.start_with?("__") ? false : __respond_to_missing?(name: name, include_all: include_all)
      end

      def method_missing(name, *arguments, **keywords, &block)
        if name.start_with?("__")
          super(name, *arguments, **keywords, &block)
        elsif __respond_to_missing?(name: name, include_all: true)
          __method_missing(name: name, arguments: arguments, keywords: keywords, block: block)
        elsif ::Kernel.respond_to?(name)
          ::Kernel.send(name, *arguments, **keywords, &block)
        elsif FALLBACK_METHODS.include?(name)
          __send__(:"__#{name}", *arguments, **keywords, &block)
        else
          super(name, *arguments, **keywords, &block)
        end
      end

      protected

      def __class
        (class << self; self end).superclass
      end

      def __to_s
        "#<#{__class}>"
      end

      def __inspect
        "#<#{__class}>"
      end

      def __eval(*arguments)
        instance_eval(*arguments)
      end

      def __respond_to_missing?(name:, include_all:)
        false
      end

      def __method_missing(name:, arguments:, keywords:, block:)
        ::Kernel.raise ::NoMethodError, "undefined name `#{name}' for #{__inspect}"
      end
    end
  end
end
