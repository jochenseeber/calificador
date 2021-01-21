# frozen_string_literal: true

require "docile"
require "ostruct"

module Calificador
  module Util
    # Extensions to core classes
    module CoreExtensions
      module_function

      def map_call_arguments(signature:, arguments:, options:)
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
            raise ArgumentError, "Required option #{name} missing for #{self} #{signature}" unless options.key?(name)

            option_names << name
          when :key
            option_names << name
          when :keyrest
            option_names += options.keys
          when :block
            # ignore
          else
            raise ArgumentError, "Illegal parameter type #{type} for #{self} #{signature}"
          end
        end

        argument_count = arguments.size
        argument_count = max_argument_count if max_argument_count && argument_count > max_argument_count

        raise ArgumentError, "Not enough parameters to call proc with #{signature}" if argument_count < min_argument_count

        arguments = arguments[0...argument_count]
        options = options.slice(*option_names)

        [arguments, options]
      end

      refine Object do
        def to_bool
          self ? true : false
        end

        def dsl_config(&block)
          target = self

          if block
            dsl = self.class.const_get(:Dsl).new(delegate: target)
            Docile.dsl_eval(dsl, &block)
          end

          target
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
          @__calificador_parent_module ||= Nil[parent_name&.then { |m| const_get(m) }]
          @__calificador_parent_module.unmask_nil
        end

        def parent_prefix
          parent_module ? "#{parent_module}::" : ""
        end

        def base_name
          @__calificador_base_name ||= if %r{(?:^|::)(?<base_name>(?:[^:]|:[^:])+)\z} =~ name
            %r{\A#<.+>\z} =~ base_name ? Nil.instance : base_name
          else
            Nil.instance
          end

          @__calificador_base_name.unmask_nil
        end

        def parent_name
          @__calificador_parent_name ||= if %r{(?<parent_name>\A.*)::} =~ name
            %r{#<} =~ parent_name ? Nil.instance : parent_name
          else
            Nil.instance
          end

          @__calificador_parent_name.unmask_nil
        end
      end

      [Method, Proc].each do |callable|
        refine callable do
          def map_call_arguments(*arguments, **options)
            CoreExtensions.map_call_arguments(signature: parameters, arguments: arguments, options: options)
          end

          def invoke(*arguments, **options, &block)
            arguments, options = map_call_arguments(*arguments, **options)
            call(*arguments, **options, &block)
          end

          def invoke_with_target(target, *arguments, **options)
            arguments, options = map_call_arguments(*arguments, **options)
            target.instance_exec(*arguments, **options, &self)
          end

          def source_location_info
            source_location ? source_location.join(":") : nil
          end
        end
      end
    end
  end
end
