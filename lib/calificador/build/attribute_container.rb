# frozen_string_literal: true

using Calificador::Util::CoreExtensions

module Calificador
  module Build
    # Factory calss
    class AttributeContainer
      class Dsl
        def initialize(delegate:)
          @delegate = delegate
          @property_type = nil
        end

        def add_attribute(name, type: nil, &config)
          type ||= @delegate.parent&.attribute(name: name)&.type || @property_type || :property
          @delegate.add_attribute(Attribute.new(name: name, type: type, config: config))
        end

        def transient(&block)
          raise ArgumentError, "Transient requires a block" if block.nil?

          old_property_type = @property_type
          @property_type = :transient

          begin
            instance_exec(self, &block)
          ensure
            @property_type = old_property_type
          end
        end

        def init_with(&block)
          raise "Initializer requires a block to create the object" if block.nil?

          @delegate.init_with = block
        end

        def before_create(&block)
          raise "Before requires a block to call" if block.nil?

          @delegate.before_create = block
        end

        def after_create(&block)
          raise "After requires a block to call" if block.nil?

          @delegate.after_create = block
        end

        def respond_to_missing?(method, include_all = false)
          if method.start_with?("__")
            super
          else
            true
          end
        end

        def method_missing(method, *arguments, &block)
          if method.start_with?("__")
            super
          else
            unless arguments.empty?
              raise ::ArgumentError, <<~ERROR
                Attribute #{method} cannot have arguments. Please use a block to configure the value
              ERROR
            end

            raise ::ArgumentError, "Attribute #{method} must have a block to provide the value" if block.nil?

            add_attribute(method, &block)
          end
        end
      end

      attr_reader :parent, :description
      attr_accessor :init_with, :before_create, :after_create

      def initialize(parent:, description:)
        @parent = parent
        @description = description.dup.freeze
        @attributes = {}
        @init_with = nil
        @before_create = nil
        @after_create = nil
      end

      def attributes
        @attributes.dup.freeze
      end

      def attribute(name:)
        @attributes[name]
      end

      def add_attribute(attribute)
        raise KeyError, "Duplicate attribute name #{name}" if @attributes.key?(attribute.name)

        @attributes[attribute.name] = attribute
      end
    end
  end
end
