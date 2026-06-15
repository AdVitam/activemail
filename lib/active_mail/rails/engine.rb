# typed: false
# frozen_string_literal: true

require 'rails/engine'

module ActiveMail
  module Rails
    class Engine < ::Rails::Engine
      config.annotations.register_extensions('active_mail') { |annotation| /<!--\s*(#{annotation}):?\s*(.*) -->/ } if config.respond_to?(:annotations)

      # Sprockets only compiles whitelisted assets; the framework entry must be
      # reachable as `stylesheet_link_tag "active_mail/active_mail"` from a host.
      initializer 'active_mail.assets' do |app|
        # Propshaft exposes config.assets but no #precompile (Sprockets-only).
        assets = app.config.respond_to?(:assets) ? app.config.assets : nil
        assets.precompile += %w[active_mail/active_mail.css] if assets.respond_to?(:precompile)
      end

      initializer 'active_mail.register_interceptor' do
        ActiveSupport.on_load(:action_mailer) do
          require 'active_mail/inliner/interceptor'
          # The interceptor honors config.register_inline_interceptor (and inliner =
          # :null) at delivery time — a boot-time check would precede host config.
          register_interceptor ActiveMail::Inliner::Interceptor
        end
      end

      rake_tasks do
        load File.expand_path('../../tasks/active_mail.rake', __dir__)
      end
    end
  end
end
