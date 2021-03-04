# typed: strict
# frozen_string_literal: true

require "ostruct"
require "sorbet-runtime"

module Calificador
  module Util
    # Extensions to core classes
    module CoreExtensions
      module ObjectMixins
        requires_ancestor Object

        sig { returns(T::Boolean) }
        def to_bool
          self ? true : false
        end
      end

      Object.include(ObjectMixins)

      module StringMixins
        requires_ancestor String

        sig { returns(String) }
        def snake_case
          gsub(%r{(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])}, "_").downcase
        end

        sig { returns(String) }
        def camel_case
          gsub(%r{(?:_+|^)([a-z])}) do
            Regexp.last_match(1)&.upcase
          end
        end
      end

      String.include(StringMixins)

      module ModuleMixins
        extend T::Helpers
        requires_ancestor Module, Kernel

        NO_MODULE = T.let(Module.new.freeze, Module)
        NO_NAME = T.let(String.new.freeze, String)

        sig { returns(T.nilable(Module)) }
        def parent_module
          parent_module = @__calificador_parent_module if instance_variable_defined?(:@__calificador_parent_module)

          unless parent_module
            parent_module = parent_name&.then { |m| const_get(m) } || NO_MODULE
            @__calificador_parent_module = T.let(parent_module, T.nilable(Module))
          end

          parent_module.equal?(NO_MODULE) ? nil : parent_module
        end

        sig { returns(String) }
        def parent_prefix
          parent_module ? "#{parent_module}::" : ""
        end

        sig { returns(T.nilable(String)) }
        def base_name
          base_name = @__calificador_base_name if instance_variable_defined?(:@__calificador_base_name)

          unless base_name
            %r{(?:^|::)(?<base_name>(?:[^:]|:[^:])+)\z} =~ name
            @__calificador_base_name = T.let(base_name, T.nilable(String))
          end

          base_name.equal?(NO_NAME) ? nil : base_name
        end

        sig { returns(T.nilable(String)) }
        def parent_name
          parent_name = @__calificador_parent_name if instance_variable_defined?(:@__calificador_parent_name)

          unless parent_name
            %r{(?<parent_name>\A.*)::} =~ name
            @__calificador_parent_name = T.let(parent_name, T.nilable(String))
          end

          parent_name.equal?(NO_NAME) ? nil : parent_name
        end

        sig { params(base: T.nilable(Module)).returns(T.nilable(String)) }
        def name_without_common_parents(base:)
          path = name&.split("::")

          result = if path
            base_path = base&.name&.split("::")
            path.remove_common_prefix(base_path).join("::") if base_path
          end

          result || name
        end
      end

      Module.include(ModuleMixins)

      module ArrayMixins
        extend T::Helpers

        sig { params(other: T::Array[BasicObject]).returns(T.self_type) }
        def remove_common_prefix(other)
          array = T.cast(self, T::Array[BasicObject])
          other_size = other.size

          array.drop_while.with_index do |element, index|
            index < other_size && element == other[index]
          end
        end
      end

      Array.include(ArrayMixins)

      module Callable
        extend T::Helpers
        interface!

        sig { abstract.returns(T::Array[[Symbol, Symbol]]) }
        def parameters; end

        sig { abstract.params(arguments: BasicObject, block: Proc).returns(BasicObject) }
        def call(*arguments, &block); end

        sig { abstract.returns(T::Array[BasicObject]) }
        def source_location; end
      end

      module CallableMixins
        extend T::Helpers
        requires_ancestor Kernel, Callable

        REQUIRED_ARGUMENT_TYPES = T.let(%i[req keyreq].freeze, T::Array[Symbol])

        sig { params(arguments: T::Array[BasicObject], keywords: KeywordHash).returns(T::Array[BasicObject]) }
        def map_call_arguments(arguments:, keywords: {})
          min_argument_count = 0
          max_argument_count = 0
          argument_splat = T.let(false, T::Boolean)
          option_names = Set.new

          keywords = Helper.extract_keywords(arguments: arguments, keywords: keywords)

          parameters.each do |type, name|
            case type
            when :req
              min_argument_count += 1
              max_argument_count += 1
            when :opt
              max_argument_count += 1
            when :rest
              argument_splat = true
            when :keyreq
              unless keywords.key?(name)
                raise ArgumentError, "Required option #{name} missing for #{self} #{parameters}"
              end

              option_names << name
            when :key
              option_names << name
            when :keyrest
              option_names += keywords.keys
            when :block
              # ignore
            else
              raise ArgumentError, "Illegal parameter type #{type} for #{self} #{parameters}"
            end
          end

          argument_count = arguments.size
          argument_count = max_argument_count if !argument_splat && argument_count > max_argument_count

          if argument_count < min_argument_count
            raise ArgumentError, "Not enough parameters to call proc with #{parameters}"
          end

          arguments = T.must(arguments[0...argument_count])

          arguments << Hash.ruby2_keywords_hash(T.unsafe(keywords).slice(*option_names)) unless option_names.empty?

          arguments
        end

        sig { params(arguments: T::Array[BasicObject], block: Proc).returns(BasicObject) }
        def invoke(*arguments, &block)
          arguments = map_call_arguments(arguments: arguments)
          T.unsafe(self).call(*arguments)
        end

        ruby2_keywords :invoke

        sig { returns(SourceLocation) }
        def source_site
          location = source_location
          SourceLocation.new(path: T.cast(location[0], String), lineno: T.cast(location[1], Integer))
        end

        sig { returns(T::Boolean) }
        def required_arguments?
          parameters.any? { |type, _name| REQUIRED_ARGUMENT_TYPES.include?(type) }
        end
      end

      Method.include(CallableMixins, Callable)
      Proc.include(CallableMixins, Callable)
    end
  end
end
