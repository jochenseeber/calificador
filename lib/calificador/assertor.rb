# frozen_string_literal: true

require "minitest"

module Calificador
  class Assertor < BasicObject
    def initialize(test:, negated: false, block: nil)
      @test = test
      @negated = negated ? true : false
      @block = block
      @value = MISSING
      @triggered = false
    end

    def respond_to?(method, include_all = false)
      __value.respond_to?(method, include_all) || super
    end

    def method_missing(method, *arguments, **options, &block) # rubocop:disable Style/MissingRespondToMissing
      if __value.respond_to?(method)
        __check(method: method, arguments: arguments, options: options, &block)
      else
        super
      end
    end

    def ==(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.value(value: __value)
        expected = ::Calificador.call_formatter.value(value: other)

        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} be equal to #{expected} (#{other.class})"
      end

      __check(method: :"==", message: message, arguments: [other])
    end

    def !=(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.value(value: __value)
        expected = ::Calificador.call_formatter.value(value: other)

        "Expected #{actual} (#{__value.class})  to#{@negated ? "" : " not"} be equal to #{expected} (#{other.class})"
      end

      __check(method: :"!=", message: message, arguments: [other])
    end

    def identical?(other)
      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.value(value: __value)
        expected = ::Calificador.call_formatter.value(value: other)

        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} be identical to #{expected} (#{other.class})"
      end

      __check(method: :"equal?", message: message, arguments: [other])
    end

    def not
      Assertor.new(test: @test, negated: !@negated, block: @block)
    end

    def raises?(*exception_classes, &block)
      @triggered = true

      block ||= @block

      ::Kernel.raise ::ArgumentError, "Exception classes must not be empty" if exception_classes.empty?
      ::Kernel.raise ::ArgumentError, "Exception assert must have a block" if block.nil?

      message = ::Kernel.proc do
        actual = ::Calificador.call_formatter.value(value: @block)
        "Expected #{actual} (#{@block}) to#{@negated ? " not" : ""} raise #{exception_classes.join(", ")}"
      end

      begin
        result = block.call

        @test.assert(@negated, message)

        result
      rescue *exception_classes => e
        @test.refute(@negated, @test.exception_details(e, message.call))
        e
      rescue ::Minitest::Assertion, ::SignalException, ::SystemExit
        ::Kernel.raise
      rescue ::Exception => e # rubocop:disable Lint/RescueException
        @test.assert(@negated, @test.exception_details(e, message.call))
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

    def __value
      if @value.equal?(MISSING)
        ::Kernel.raise ::StandardError, "No block set for assertion" if @block.nil?

        @value = @block.call
      end

      @value
    end

    def __check(method:, message: nil, arguments: [], options: {}, &block)
      @triggered = true

      result = __value.send(method, *arguments, **options, &block)

      message ||= ::Kernel.proc do
        actual = ::Calificador.call_formatter.value(value: __value)
        call = ::Calificador.call_formatter.method(method: method, arguments: arguments, options: options)
        "Expected #{actual} (#{__value.class}) to#{@negated ? " not" : ""} #{call}"
      end

      if @negated
        @test.refute(result, message)
      else
        @test.assert(result, message)
      end

      result
    end
  end
end
