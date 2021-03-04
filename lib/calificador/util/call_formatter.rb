# typed: strict
# frozen_string_literal: true

require "pp"

module Calificador
  module Util
    class CallFormatter
      include Util::EscapeHatch

      sig { params(name: Symbol, arguments: T::Array[BasicObject], keywords: KeywordHash, block: T.nilable(Proc)).returns(String) }
      def format_method(name:, arguments: [], keywords: {}, block: nil)
        keywords = Helper.extract_keywords(arguments: arguments, keywords: keywords)

        info = ::StringIO.new
        info << name

        unless arguments.empty? && keywords.empty?
          info << "("

          arguments.each_with_index do |argument, i|
            info << ", " unless i.zero?
            append_value(value: argument, out: info)
          end

          keywords.each_with_index do |(keyword, value), i|
            info << ", " unless i.zero? && arguments.empty?
            info << keyword << ": "
            append_value(value: value, out: info)
          end

          info << ")"
        end

        info.string
      end

      sig { params(value: BasicObject).returns(String) }
      def format_value(value:)
        append_value(value: value, out: StringIO.new).string
      end

      sig { params(value: BasicObject, out: StringIO).returns(StringIO) }
      def append_value(value:, out:)
        PP.singleline_pp(value, out)
      end
    end
  end
end
