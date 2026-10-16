# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Root element is a layout table: its reset attributes are fixed, not author-overridable.
    class TableComponent < Base
      extend T::Sig
      extend T::Helpers

      abstract!

      private

      sig { override.overridable.returns(T::Array[String]) }
      def consumed_attributes
        TABLE_RESET_ATTRIBUTES
      end
    end
  end
end
