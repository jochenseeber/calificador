# frozen_string_literal: true

require "minitest"

using Calificador::Util::CoreExtensions

module Calificador
  # Test subject key
  class Key
    DEFAULT_TRAIT = :"<default>"
    INHERITED_TRAIT = :"<inherited>"

    class << self
      def [](type, trait = DEFAULT_TRAIT)
        new(type: type, trait: trait)
      end
    end

    attr_reader :type, :trait

    def initialize(type:, trait: DEFAULT_TRAIT)
      raise ArgumentError, "Illegal trait value #{trait}" if trait == INHERITED_TRAIT

      @type = type
      @trait = trait || DEFAULT_TRAIT
    end

    def hash
      (@type.hash * 31) + @trait.hash
    end

    def ==(other)
      (@type == other.type) && (@trait == other.trait)
    end

    alias_method :eql?, :==

    def to_s
      trait == DEFAULT_TRAIT ? type.to_s : "#{type} (#{trait})"
    end

    alias_method :inspect, :to_s

    def with(trait)
      case trait
      when INHERITED_TRAIT
        self
      when nil, DEFAULT_TRAIT
        @trait == DEFAULT_TRAIT ? self : Key.new(type: @type, trait: DEFAULT_TRAIT)
      else
        trait == @trait ? self : Key.new(type: @type, trait: trait)
      end
    end

    def trait?
      @trait != DEFAULT_TRAIT
    end
  end
end
