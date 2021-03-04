# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    class ArgumentMatcher
      sig { params(keywords: T::Array[Symbol], values: T::Array[BasicObject]).void }
      def initialize(keywords:, values:)
        @keywords = T.let(keywords.dup, T::Array[Symbol])
        @keyword_index = T.let(0, Integer)
        @keyword_count = T.let(keywords.size, Integer)
        @values = T.let(values.dup, T::Array[BasicObject])
        @value_index = T.let(0, Integer)
        @value_count = T.let(values.size, Integer)
      end

      sig { params(block: T.proc.params(matcher: ArgumentMatcher, value: BasicObject).void).void }
      def process(&block)
        while @value_index < @value_count
          block.call(self, @values[@value_index])
          @value_index += 1
        end
      end

      sig { params(candidates: Symbol, consume: T::Boolean).returns(Symbol) }
      def accept(*candidates, consume: true)
        @keyword_index += 1 while @keyword_index < @keyword_count && candidates.none?(@keywords[@keyword_index])

        reject if @keyword_index >= @keyword_count

        keyword = T.must(@keywords[@keyword_index])
        @keyword_index += 1 if consume

        keyword
      end

      sig { returns(T.noreturn) }
      def reject
        raise ArgumentError, <<~MESSAGE.gsub("\n", " ")
          Illegal value '#{@values[@value_index]}' at position #{@value_index}. Expected keywords are
          #{@keywords.join(",")}
        MESSAGE
      end
    end
  end
end
