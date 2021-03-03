# frozen_string_literal: true

require "ostruct"

module Calificador
  module Util
    # Extensions to core classes
    module CoreExtensions
      module_function

      REQUIRED_ARGUMENT_TYPES = %i[req keyreq].freeze

      def map_call_arguments(signature:, arguments:, keywords:)
        min_argument_count = 0
        max_argument_count = 0
        option_names = Set.new

        signature.each do |type, name|
          case type
          when :req
            min_argument_count += 1
            max_argument_count += 1
          when :opt
            max_argument_count += 1
          when :rest
            max_argument_count = nil
          when :keyreq
            raise ArgumentError, "Required option #{name} missing for #{self} #{signature}" unless keywords.key?(name)

            option_names << name
          when :key
            option_names << name
          when :keyrest
            option_names += keywords.keys
          when :block
            # ignore
          else
            raise ArgumentError, "Illegal parameter type #{type} for #{self} #{signature}"
          end
        end

        argument_count = arguments.size
        argument_count = max_argument_count if max_argument_count && argument_count > max_argument_count

        if argument_count < min_argument_count
          raise ArgumentError,
                "Not enough parameters to call proc with #{signature}"
        end

        arguments = arguments[0...argument_count]
        keywords = keywords.slice(*option_names)

        [arguments, keywords]
      end

      refine Object do
        def to_bool
          self ? true : false
        end
      end

      refine String do
        def snake_case
          gsub(%r{(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])}, "_").downcase
        end

        def camel_case
          gsub(%r{(?:_+|^)([a-z])}) do
            Regexp.last_match(1).upcase
          end
        end
      end

      refine Module do
        def parent_module
          if !instance_variable_defined?(:@__calificador_parent_module) || @__calificador_parent_module.nil?
            @__calificador_parent_module = Nil[parent_name&.then { |m| const_get(m) }]
          end

          @__calificador_parent_module.unmask_nil
        end

        def parent_prefix
          parent_module ? "#{parent_module}::" : ""
        end

        def base_name
          if !instance_variable_defined?(:@__calificador_base_name) || @__calificador_base_name.nil?
            @__calificador_base_name = if %r{(?:^|::)(?<base_name>(?:[^:]|:[^:])+)\z} =~ name
              Nil[base_name]
            else
              Nil.instance
            end
          end

          @__calificador_base_name.unmask_nil
        end

        def parent_name
          if !instance_variable_defined?(:@__calificador_parent_name) || @__calificador_parent_name.nil?
            @__calificador_parent_name = if %r{(?<parent_name>\A.*)::} =~ name
              parent_name
            else
              Nil.instance
            end
          end

          @__calificador_parent_name.unmask_nil
        end

        def name_without_common_parents(base:)
          path = name&.split("::")

          result = if path
            base_path = base&.name&.split("::")
            path.remove_common_prefix(base_path).join("::") if base_path
          end

          result || name
        end
      end

      refine Array do
        def remove_common_prefix(other)
          drop_while.with_index do |element, index|
            index < size && element == other[index]
          end
        end
      end

      [Method, Proc].each do |callable|
        refine callable do
          def map_call_arguments(*arguments, **keywords)
            CoreExtensions.map_call_arguments(signature: parameters, arguments: arguments, keywords: keywords)
          end

          def invoke(*arguments, **keywords, &block)
            arguments, keywords = map_call_arguments(*arguments, **keywords)
            call(*arguments, **keywords, &block)
          end

          def invoke_with_target(target, *arguments, **keywords)
            arguments, keywords = map_call_arguments(*arguments, **keywords)
            target.instance_exec(*arguments, **keywords, &self)
          end

          def source_location_info
            source_location ? source_location.join(":") : nil
          end

          def required_arguments?
            parameters.any? { |type, _name| REQUIRED_ARGUMENT_TYPES.include?(type) }
          end
        end
      end
    end
  end
end
