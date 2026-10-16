# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module AssetPipeline
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { params(app: T.untyped).void }
      def initialize(app)
        @app = T.let(app, T.untyped)
        @cache = T.let({}, T::Hash[String, String])
      end

      sig { params(logical_path: String).returns(T.nilable(String)) }
      def read(logical_path)
        return fetch(logical_path) unless cache?

        cached = @cache[logical_path]
        return cached if cached

        fetch(logical_path).tap { |css| @cache[logical_path] = css if css }
      end

      sig { params(_paths: T::Array[String]).void }
      def register_precompile(_paths); end

      private

      sig { abstract.params(logical_path: String).returns(T.nilable(String)) }
      def fetch(logical_path); end

      sig { returns(T.untyped) }
      attr_reader :app

      sig { returns(T::Boolean) }
      def cache?
        !app.config.enable_reloading
      end
    end
  end
end
