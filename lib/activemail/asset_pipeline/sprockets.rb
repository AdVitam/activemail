# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module AssetPipeline
    class Sprockets < Base
      extend T::Sig

      sig { override.params(paths: T::Array[String]).void }
      def register_precompile(paths)
        app.config.assets.precompile += paths
      end

      private

      # app.assets is the live environment (compile = true); with precompiled
      # assets it is nil and only the manifest can resolve the logical path.
      sig { override.params(logical_path: String).returns(T.nilable(String)) }
      def fetch(logical_path)
        environment = app.assets
        return environment.find_asset(logical_path)&.to_s if environment

        manifest_source(logical_path)
      end

      sig { params(logical_path: String).returns(T.nilable(String)) }
      def manifest_source(logical_path)
        manifest = app.assets_manifest
        compiled = manifest&.assets&.[](logical_path)
        return unless compiled

        path = File.join(manifest.directory, compiled)
        File.read(path) if File.file?(path)
      end
    end
  end
end
