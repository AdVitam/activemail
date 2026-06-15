# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  # Reads a compiled CSS asset's bytes (Sprockets or Propshaft, by duck-type) — the
  # bytes, not a digest URL, are what the Premailer adapter needs to inline.
  module CompiledStylesheet
    class << self
      extend T::Sig

      # '' (not nil) on a miss: callers embed the result verbatim, and a missing
      # asset must degrade to an empty <style>, never interpolate "nil" into HTML.
      sig { params(logical_path: String).returns(String) }
      def read(logical_path)
        sprockets_source(logical_path) || propshaft_source(logical_path) || ''
      end

      private

      # Sprockets: config.assets.compile (dev) resolves logical paths in-memory;
      # precompiled (prod) resolves through the manifest. #find_asset covers both.
      sig { params(logical_path: String).returns(T.nilable(String)) }
      def sprockets_source(logical_path)
        assets = rails_assets_environment
        return unless assets.respond_to?(:find_asset)

        asset = assets.find_asset(logical_path)
        asset&.source&.to_s
      end

      # Propshaft: the load_path resolves a logical path to a compiled file on disk.
      sig { params(logical_path: String).returns(T.nilable(String)) }
      def propshaft_source(logical_path)
        assets = rails_assets
        load_path = assets.respond_to?(:load_path) ? assets.load_path : nil
        return unless load_path.respond_to?(:find)

        asset = load_path.find(logical_path)
        asset&.path && File.exist?(asset.path) ? File.read(asset.path) : nil
      end

      # config.assets.environment is the Sprockets::Environment; absent under Propshaft.
      sig { returns(T.untyped) }
      def rails_assets_environment
        assets = rails_assets
        assets.respond_to?(:environment) ? assets.environment : nil
      end

      sig { returns(T.untyped) }
      def rails_assets
        return unless Object.const_defined?(:Rails)

        rails = Object.const_get(:Rails)
        app = rails.respond_to?(:application) ? rails.application : nil
        config = app&.config
        config.respond_to?(:assets) ? config.assets : nil
      end
    end
  end
end
