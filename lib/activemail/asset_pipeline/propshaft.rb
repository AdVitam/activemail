# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module AssetPipeline
    class Propshaft < Base
      extend T::Sig

      private

      sig { override.params(logical_path: String).returns(T.nilable(String)) }
      def fetch(logical_path)
        app.assets.load_path.find(logical_path)&.content&.force_encoding(Encoding::UTF_8)
      end
    end
  end
end
