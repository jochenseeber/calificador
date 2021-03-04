# typed: false
# frozen_string_literal: true

module Calificador
  module Util
    # Escape hatch for stuff Sorbet does not like
    module EscapeHatch
      module_function

      sig { params(object: BasicObject).returns(Class) }
      def singleton_class_of(object)
        (class << object; self; end)
      end

      # Get singleton class of object without type checking
      #
      # If you really don't want to call any methods on the object, you can
      # use this version with disabled type checking, so Sorbet does not call
      # is_a?
      sig { params(object: BasicObject).returns(Class).checked(:never) }
      def unchecked_singleton_class_of(object)
        (class << object; self; end)
      end

      sig { params(object: BasicObject, try_without_method_calls: T::Boolean).returns(Class) }
      def class_of(object, try_without_method_calls: true)
        if !try_without_method_calls && object.is_a?(Object)
          object.class
        else
          begin
            (class << object; self; end).superclass
          rescue TypeError
            object.class
          end
        end
      end

      # Get class of object without type checking
      #
      # If you really don't want to call any methods on the object, you can
      # use this version with disabled type checking, so Sorbet does not call
      # is_a?
      sig { params(object: BasicObject, try_without_method_calls: T::Boolean).returns(Class).checked(:never) }
      def unchecked_class_of(object, try_without_method_calls: true)
        if !try_without_method_calls && object.is_a?(Object)
          object.class
        else
          begin
            (class << object; self; end).superclass
          rescue TypeError
            object.class
          end
        end
      end
    end
  end
end
