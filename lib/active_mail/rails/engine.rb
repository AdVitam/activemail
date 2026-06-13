# typed: false
# frozen_string_literal: true

require 'rails/engine'

module ActiveMail
  module Rails
    class Engine < ::Rails::Engine
      config.annotations.register_extensions('active_mail') { |annotation| /<!--\s*(#{annotation}):?\s*(.*) -->/ } if config.respond_to?(:annotations)

      initializer 'active_mail.register_interceptor' do
        next unless ActiveMail.configuration.register_inline_interceptor

        ActiveSupport.on_load(:action_mailer) do
          require 'active_mail/inliner/interceptor'
          # config.inliner = :null also short-circuits the interceptor at runtime.
          register_interceptor ActiveMail::Inliner::Interceptor
        end
      end

      rake_tasks do
        load File.expand_path('../../tasks/active_mail.rake', __dir__)
      end
    end
  end
end
