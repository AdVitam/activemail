# typed: false
# frozen_string_literal: true

require 'rails/engine'
require 'activemail/rails/compiled_stylesheet'

module ActiveMail
  module Rails
    class Engine < ::Rails::Engine
      config.annotations.register_extensions('activemail') { |annotation| /<!--\s*(#{annotation}):?\s*(.*) -->/ } if config.respond_to?(:annotations)

      # Sprockets only compiles whitelisted assets; the framework entry must be
      # reachable as `stylesheet_link_tag "activemail/activemail"` from a host.
      initializer 'activemail.assets' do |app|
        # Propshaft exposes config.assets but no #precompile (Sprockets-only).
        assets = app.config.respond_to?(:assets) ? app.config.assets : nil
        assets.precompile += %w[activemail/activemail.css] if assets.respond_to?(:precompile)
      end

      initializer 'activemail.action_mailer' do
        ActiveSupport.on_load(:action_mailer) do
          require 'activemail/inliner/interceptor'
          # The interceptor honors config.register_inline_interceptor (and inliner =
          # :null) at delivery time — a boot-time check would precede host config.
          register_interceptor ActiveMail::Inliner::Interceptor
          # activemail_inline_styles must be available to mailer layouts/views.
          helper ActiveMail::StylesHelper
        end
      end

      rake_tasks do
        load File.expand_path('../../tasks/activemail.rake', __dir__)
      end
    end
  end
end
