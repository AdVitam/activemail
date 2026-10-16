# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module AssetPipeline
    class Null < Base
      extend T::Sig

      private

      sig { override.params(_logical_path: String).returns(T.nilable(String)) }
      def fetch(_logical_path)
        nil
      end
    end
  end
end
