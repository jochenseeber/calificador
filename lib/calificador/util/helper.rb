# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    module Helper
      module_function

      EMPTY_KEYWORDS = ::T.let({}.freeze, KeywordHash)

      sig { params(arguments: ::T::Array[BasicObject], keywords: KeywordHash).returns(KeywordHash) }
      def extract_keywords(arguments:, keywords: EMPTY_KEYWORDS)
        last_argument = arguments.last

        if EscapeHatch.class_of(last_argument) <= ::Hash && ::Hash.ruby2_keywords_hash?(last_argument)
          unless keywords.empty?
            ::Kernel.raise ::ArgumentError, "Keywords must be empty because arguments contains a keyword hash"
          end

          arguments.pop
          ::T.cast(last_argument, KeywordHash)
        else
          keywords
        end
      end
    end
  end
end
