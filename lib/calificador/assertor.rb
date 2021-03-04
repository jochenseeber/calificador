# typed: strict
# frozen_string_literal: true

require "minitest"
require "singleton"

module Calificador
  class Assertor < Util::ProxyObject
    include Util::EscapeHatch

    Message = ::T.type_alias { ::T.any(::String, ::T.proc.returns(::String)) }
    Assertion = ::T.type_alias { ::T.proc.returns(::Object) }

    module Handler
      interface!

      sig { abstract.params(condition: ::Object, message: Message).void }
      def assert(condition, message); end

      sig { abstract.params(condition: ::Object, message: Message).void }
      def refute(condition, message); end
    end

    class DefaultHandler
      include Handler
      include Singleton

      sig { override.params(condition: ::Object, message: Message).void }
      def assert(condition, message)
        ::Kernel.raise ::Minitest::Assertion, message unless condition
      end

      sig { override.params(condition: ::Object, message: Message).void }
      def refute(condition, message)
        ::Kernel.raise ::Minitest::Assertion, message if condition
      end
    end

    sig { params(handler: Handler, negated: ::T::Boolean, block: ::T.nilable(Assertion)).void }
    def initialize(handler: DefaultHandler.instance, negated: false, block: nil)
      super()

      @handler = handler
      @negated = ::T.let(negated ? true : false, ::T::Boolean)
      @block = block
      @value = ::T.let(MISSING, ::Object)
      @triggered = ::T.let(false, ::T::Boolean)
    end

    sig { params(other: ::Object).returns(::T::Boolean) }
    def ==(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{class_of(__value)}) to#{@negated ? " not" : ""} be equal to #{expected} (#{class_of(other)})"
      end

      ::T.cast(__check(name: :"==", message: message, arguments: [other]), ::T::Boolean)
    end

    sig { params(other: ::Object).returns(::T::Boolean) }
    def !=(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{class_of(__value)})  to#{@negated ? "" : " not"} be equal to #{expected} (#{class_of(other)})"
      end

      ::T.cast(__check(name: :"!=", message: message, arguments: [other]), ::T::Boolean)
    end

    sig { params(other: ::Object).returns(::T::Boolean) }
    def identical?(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{class_of(__value)}) to#{@negated ? " not" : ""} be identical to #{expected} (#{class_of(other)})"
      end

      ::T.cast(__check(name: :"equal?", message: message, arguments: [other]), ::T::Boolean)
    end

    sig { returns(Assertor) }
    def not
      self # Assertor.new(handler: @handler, negated: !@negated, block: @block)
    end

    sig { params(exception_classes: ::T.class_of(::Exception), block: ::T.nilable(Assertion)).returns(::Object) }
    def raises?(*exception_classes, &block)
      @triggered = true

      if @block
        ::Kernel.raise ::ArgumentError, "Block cannot be given sind assert was created with one" if block

        block = @block
      else
        ::Kernel.raise ::ArgumentError, "Block required since assert has created without one" unless block
      end

      ::Kernel.raise ::ArgumentError, "::Exception classes must not be empty" if exception_classes.empty?

      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: block)
        "Expected #{actual} (#{block}) to#{@negated ? " not" : ""} raise #{exception_classes.join(", ")}"
      end

      begin
        result = block.call

        __assert(@negated, message: message)

        result
      rescue *exception_classes => e
        __refute(@negated, message: __exception_details(e, message: message))
        e
      rescue ::Minitest::Assertion, ::SystemExit, ::SignalException
        ::Kernel.raise
      rescue ::Exception => e # rubocop:disable Lint/RescueException
        __assert(@negated, message: __exception_details(e, message: message))
      end
    end

    sig { void }
    def __check_triggered
      unless @triggered
        source_site = @block ? @block.source_site : ::Calificador::Util::SourceLocation.unknown

        ::Kernel.raise ::StandardError, <<~MESSAGE.gsub("\n", " ")
          Assertor (#{source_site}) was not triggered. You probably need to call a method to
          check for something, our your check must be changed to use a method not defined on ::Object.
        MESSAGE
      end
    end

    sig { params(type: ::Module).returns(::T::Boolean) }
    def is_a?(type)
      type === self # rubocop:disable Style/CaseEquality
      # if type == Assertor
      #   # We'll answer truthfully if we're asked directly, otherwise Sorbet will break
      #   true
      # else
      #   # Lie for all other types
      #   message = ::Kernel.proc do
      #     actual = ::Calificador.call_formatter.format_value(value: __value)

      #     "Expected #{actual} (#{class_of(__value)}) to#{@negated ? " not" : ""} be a #{type}"
      #   end

      #   ::T.cast(__check(name: :"is_a?", message: message, arguments: [type]), ::T::Boolean)
      # end
    end

    protected

    sig { params(name: ::Symbol, include_all: ::T::Boolean).returns(::T::Boolean) }
    def __respond_to_missing?(name:, include_all:)
      __value.respond_to?(name, false)
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
  if __value.respond_to?(name)
        message = ::Kernel.proc do
          actual = ::Calificador.call_formatter.format_value(value: __value)
          call = ::Calificador.call_formatter.format_method(name: name, arguments: arguments, block: block)
          "Expected #{actual} (#{class_of(__value)}) to#{@negated ? " not" : ""} #{call}"
        end

        __check(name: name, message: message, arguments: arguments, block: block)
      else
        super
      end
    end

    ruby2_keywords :__method_missing

    sig { returns(::Object) }
    def __value
      if @value.equal?(MISSING)
        ::Kernel.raise ::StandardError, "No block set for assertion" if @block.nil?

        @value = @block.call
      end

      @value
    end

    sig do
      params(
        name: ::Symbol,
        message: Message,
        arguments: BasicObject,
        block: ::T.nilable(::Proc)
      ).returns(::Object)
    end
    def __check(name:, message:, arguments: [], block: nil)
      @triggered = true

      result = begin
        ::T.unsafe(__value).__send__(name, *arguments, &block)
      rescue ::StandardError => e
        ::Kernel.raise ::Minitest::UnexpectedError, e
      end

      if @negated
        __refute(result, message: message)
      else
        __assert(result, message: message)
      end

      result
    end

    sig { params(condition: ::Object, message: Message).void }
    def __assert(condition, message:)
      message = message.call if !condition && message.is_a?(::Proc)

      @handler.assert(condition, message)
    end

    sig { params(condition: ::Object, message: Message).void }
    def __refute(condition, message:)
      message = message.call if condition && message.is_a?(::Proc)

      @handler.refute(condition, message)
    end

    sig { params(exception: ::Exception, message: Message).returns(::String) }
    def __exception_details(exception, message:)
      message = message.call if message.is_a?(::Proc)

      [
        message,
        "Class: <#{exception.class}>",
        "Message: #{exception.message}",
        "---Backtrace---",
        exception.backtrace&.map(&:to_s) || "<missing>",
        "---------------",
      ].flatten.join("\n")
    end
  end
end
