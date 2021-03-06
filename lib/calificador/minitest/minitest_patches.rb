# typed: strict
# frozen_string_literal: true

require "minitest/test"

module Calificador
  module Minitest
    # Patches to minitest classes
    module MinitestPatches
      # Patches to Minitest::Assertion
      module AssertionMethods
        requires_ancestor ::Minitest::Assertion

        sig { returns(String) }
        def location
          last_before_assertion = ""

          backtrace&.reverse_each do |s|
            break if s =~ %r{assertor|in .(assert|refute|flunk|pass|fail|raise|must|wont)}

            last_before_assertion = s
          end

          last_before_assertion.sub(%r{:in .*$}, "")
        end
      end
    end
  end
end
