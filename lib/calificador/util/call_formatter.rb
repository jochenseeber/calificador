# frozen_string_literal: true

require "pp"

module Calificador
  module Util
    class CallFormatter
      def method(method:, arguments: [], options: {})
        info = ::StringIO.new
        info << method

        unless arguments.empty? && options.empty?
          info << "("

          arguments.each_with_index do |argument, i|
            info << ", " unless i.zero?
            append_value(value: argument, out: info)
          end

          options.each_with_index do |(name, value), i|
            info << ", " unless i.zero? && arguments.empty?
            info << name << ": "
            append_value(value: value, out: info)
          end

          info << ")"
        end

        info.string
      end

      def value(value:)
        append_value(value: value, out: StringIO.new).string
      end

      def append_value(value:, out:)
        PP.singleline_pp(value, out)
      end
    end
  end
end
