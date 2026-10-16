# typed: false
# frozen_string_literal: true

require 'rails/engine'
require 'activemail/asset_pipeline'
require 'activemail/rails/rendering'

module ActiveMail
  module Rails
    class Engine < ::Rails::Engine
      # Sprockets only compiles whitelisted assets (a no-op under Propshaft).
      initializer 'activemail.assets' do |app|
        ActiveMail::AssetPipeline.for(app).register_precompile(%w[activemail/activemail.css])
      end

      initializer 'activemail.annotations' do |app|
        ActiveSupport.on_load(:action_view) do
          extensions = ActionView::Template.template_handler_extensions.grep(/\Ainky-/)
          app.config.annotations.register_extensions(*extensions) { |annotation| /<!--\s*(#{annotation}):?\s*(.*) -->/ }
        end
      end

      initializer 'activemail.action_mailer' do
        ActiveSupport.on_load(:action_mailer) do
          prepend ActiveMail::Rails::Rendering::MailerExtension

          helper ActiveMail::StylesHelper
        end
      end

      rake_tasks do
        load File.expand_path('../../tasks/activemail.rake', __dir__)
      end
    end
  end
end
