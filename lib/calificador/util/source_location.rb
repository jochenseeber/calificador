# typed: strict
# frozen_string_literal: true

module Calificador
  module Util
    class SourceLocation < T::Struct
      include Util::EscapeHatch

      SOURCE_PATTERN = T.let(%r{/lib/calificador/}.freeze, Regexp)

      prop :path, String
      prop :lineno, Integer

      @unknown = T.let(SourceLocation.new(path: "", lineno: -1), SourceLocation)

      class << self
        sig { returns(SourceLocation) }
        attr_reader :unknown

        sig { returns(SourceLocation) }
        def caller_site
          location = Kernel.caller_locations&.find do |l|
            SOURCE_PATTERN !~ l.path
          end

          if location
            SourceLocation.new(path: location.path || "<unknown>", lineno: location.lineno)
          else
            SourceLocation.unknown
          end
        end
      end

      sig { returns(String) }
      def to_s
        path.empty? ? "<unknown>" : "#{path}:#{lineno}"
      end

      sig { params(other: BasicObject).returns(::T.nilable(::T::Boolean)) }
      def ==(other)
        if SourceLocation === other # rubocop:disable Style/CaseEquality
          @path == other.path && @lineno == other.lineno
        else
          false
        end
      end

      alias_method :eql?, :==

      sig { returns(Integer) }
      def hash
        @path.hash * 31 + @lineno.hash
      end
    end
  end
end
