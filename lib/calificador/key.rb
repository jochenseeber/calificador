# frozen_string_literal: true

require "minitest"

using Calificador::Util::CoreExtensions

module Calificador
  # Test subject key
  class Key
    NO_TRAIT = :"<none>"
    DEFAULT_TRAIT = :"<default>"

    class << self
      def [](type, trait = NO_TRAIT)
        new(type: type, trait: trait)
      end
    end

    attr_reader :type, :trait

    def initialize(type:, trait: NO_TRAIT)
      trait ||= NO_TRAIT

      raise ArgumentError, "Type must be a #{Module}, not '#{type}' (#{type.class})" unless type.is_a?(Module)
      raise ArgumentError, "Trait must be a #{Symbol}" unless trait.is_a?(Symbol)

      @type = type
      @trait = trait
    end

    def trait?
      @trait != NO_TRAIT && @trait != DEFAULT_TRAIT
    end

    def default_trait?
      @trait == DEFAULT_TRAIT
    end

    def hash
      (@type.hash * 31) + @trait.hash
    end

    def ==(other)
      other.is_a?(Key) && (@type == other.type) && (@trait == other.trait)
    end

    alias_method :eql?, :==

    def to_s(base_module: nil)
      type_name = @type.name_without_common_parents(base: base_module)
      @trait == NO_TRAIT ? type_name : "#{type_name} (#{@trait})"
    end

    alias_method :inspect, :to_s

    def with(trait)
      case trait
      when nil, DEFAULT_TRAIT
        self
      else
        trait == @trait ? self : Key.new(type: @type, trait: trait)
      end
    end

    def with_default(key)
      if @trait == DEFAULT_TRAIT && @trait != key.trait
        Key[@type, key.trait]
      else
        self
      end
    end
  end
end
