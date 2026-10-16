# typed: false
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'asset_pipeline/base'
require_relative 'asset_pipeline/sprockets'
require_relative 'asset_pipeline/propshaft'
require_relative 'asset_pipeline/null'

module ActiveMail
  # Strategy over the host's asset pipeline: the inliner needs the compiled CSS
  # bytes, which neither pipeline exposes through a common API.
  module AssetPipeline
    class << self
      extend T::Sig

      # Constant detection, never respond_to?: Sprockets' config.assets is an
      # OrderedOptions that answers respond_to? for any key.
      sig { params(app: T.untyped).returns(ActiveMail::AssetPipeline::Base) }
      def for(app)
        if defined?(::Sprockets::Railtie)
          Sprockets.new(app)
        elsif defined?(::Propshaft)
          Propshaft.new(app)
        else
          Null.new(app)
        end
      end

      sig { returns(ActiveMail::AssetPipeline::Base) }
      def current
        @current ||= T.let(self.for(::Rails.application), T.nilable(ActiveMail::AssetPipeline::Base))
      end
    end
  end
end
