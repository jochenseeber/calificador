# frozen_string_literal: true

require "minitest"

module Calificador
  class Assertor < Util::ProxyObject
    def initialize(handler:, negated: false, block: nil)
      @handler = handler
      @negated = negated ? true : false
      @block = block
      @value = MISSING
      @triggered = false
    end

    def ==(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} be equal to #{expected} (#{other.class})"
      end

      __check(name: :"==", message: message, arguments: [other])
    end

    def !=(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{__value.class})  to#{@negated ? "" : " not"} be equal to #{expected} (#{other.class})"
      end

      __check(name: :"!=", message: message, arguments: [other])
    end

    def identical?(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        expected = ::Calificador.call_formatter.format_value(value: other)

        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} be identical to #{expected} (#{other.class})"
      end

      __check(name: :"equal?", message: message, arguments: [other])
    end

    def not
      Assertor.new(handler: @handler, negated: !@negated, block: @block)
    end

    def raises?(*exception_classes, &block)
      @triggered = true

      block ||= @block

      ::Kernel.raise ::ArgumentError, "Exception classes must not be empty" if exception_classes.empty?
      ::Kernel.raise ::ArgumentError, "Exception assert must have a block" if block.nil?

      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: @block)
        "Expected #{actual} (#{@block}) to#{@negated ? " not" : ""} raise #{exception_classes.join(", ")}"
      end

      begin
        result = block.call

        __assert(@negated, message: message)

        result
      rescue *exception_classes => e
        __refute(@negated, message: __exception_details(e, message: message))
        e
      rescue ::Minitest::Assertion, ::SignalException, ::SystemExit
        ::Kernel.raise
      rescue ::Exception => e # rubocop:disable Lint/RescueException
        __assert(@negated, message: __exception_details(e, message: message))
      end
    end

    def __check_triggered
      unless @triggered
        ::Kernel.raise ::StandardError, <<~MESSAGE.gsub("\n", " ")
          Assertor (#{@block.source_location.join(":")}) was not triggered. You probably need to call a method to
          check for something, our your check must be changed to use a method not defined on BasicObject.
        MESSAGE
      end
    end

    protected

    def __respond_to_missing?(name:, include_all:)
      __value.respond_to?(name, false)
    end

    def __method_missing(name:, arguments:, keywords:, block:)
      if __value.respond_to?(name)
        __check(name: name, arguments: arguments, keywords: keywords, &block)
      else
        super
      end
    end

    def __value
      if @value.equal?(MISSING)
        ::Kernel.raise ::StandardError, "No block set for assertion" if @block.nil?

        @value = @block.call
      end

      @value
    end

    def __check(name:, message: nil, arguments: [], keywords: {}, &block)
      @triggered = true

      result = begin
        __value.send(name, *arguments, **keywords, &block)
      rescue ::StandardError => e
        raise ::Minitest::UnexpectedError, e
      end

      message ||= ::Kernel.proc do
        actual = ::Calificador.call_formatter.format_value(value: __value)
        call = ::Calificador.call_formatter.format_method(name: name, arguments: arguments, keywords: keywords)
        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} #{call}"
      end

      if @negated
        __refute(result, message: message)
      else
        __assert(result, message: message)
      end

      result
    end

    def __assert(condition, message:)
      message = message.call if !condition && message.is_a?(::Proc)

      @handler.assert(condition, message)
    end

    def __refute(condition, message:)
      message = message.call if condition && message.is_a?(::Proc)

      @handler.refute(condition, message)
    end

    def __exception_details(exception, message:)
      message = message.call if message.is_a?(::Proc)

      [
        message,
        "Class: <#{exception.class}>",
        "Message: #{exception.message}",
        "---Backtrace---",
        exception.backtrace.map(&:to_s),
        "---------------",
      ].flatten.join("\n")
    end
  end
end
