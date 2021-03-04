# typed: strict
# frozen_string_literal: true

require "minitest"

module Calificador
  # Test subject key
  class Key
    include Util::EscapeHatch

    NO_TRAIT = :"<none>"
    DEFAULT_TRAIT = :"<default>"

    class << self
      sig { params(type: Module, trait: T.nilable(Symbol)).returns(Key) }
      def [](type, trait = NO_TRAIT)
        new(type: type, trait: trait)
      end
    end

    sig { returns(Module) }
    attr_reader :type

    sig { returns(Symbol) }
    attr_reader :trait

    sig { params(type: Module, trait: T.nilable(Symbol)).void }
    def initialize(type:, trait: NO_TRAIT)
      @type = type
      @trait = T.let(trait || NO_TRAIT, Symbol)
    end

    sig { returns(T::Boolean) }
    def trait?
      @trait != NO_TRAIT && @trait != DEFAULT_TRAIT
    end

    sig { returns(T::Boolean) }
    def default_trait?
      @trait == DEFAULT_TRAIT
    end

    sig { returns(Integer) }
    def hash
      (@type.hash * 31) + @trait.hash
    end

    sig { params(other: BasicObject).returns(T::Boolean) }
    def ==(other)
      if class_of(other) == Key
        key = T.cast(other, Key)
        (@type == key.type) && (@trait == key.trait) ? true : false
      else
        false
      end
    end

    alias_method :eql?, :==

    sig { params(base_module: T.nilable(Module)).returns(String) }
    def to_s(base_module: nil)
      type_name = @type.name_without_common_parents(base: base_module) || "<anonymous>"
      @trait == NO_TRAIT ? type_name : "#{type_name} (#{@trait})"
    end

    alias_method :inspect, :to_s

    sig { params(trait: T.nilable(Symbol)).returns(Key) }
    def with(trait)
      case trait
      when nil, DEFAULT_TRAIT
        self
      else
        trait == @trait ? self : Key.new(type: @type, trait: trait)
      end
    end

    sig { params(key: Key).returns(Key) }
    def with_default(key)
      if @trait == DEFAULT_TRAIT && @trait != key.trait
        Key[@type, key.trait]
      else
        self
      end
    end
  end
end
