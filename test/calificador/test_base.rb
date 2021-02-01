# frozen_string_literal: true

require "simplecov" # Must go first

SimpleCov.start do
  add_filter "/test/"
  enable_coverage :branch
end

require "minitest/autorun" # Must go second

require "calificador"
