# frozen_string_literal: true

require 'rails/generators'

module ActiveMail
  module Generators
    # Ejects the engine's default mailer layout + partials into the host app,
    # where same-named files take precedence and can be customized.
    class ViewsGenerator < ::Rails::Generators::Base
      desc 'Copy ActiveMail default layout views into the host app for customization'
      source_root File.expand_path('../../../app/views/layouts/active_mail', __dir__)

      def copy_views
        directory '.', File.join('app', 'views', 'layouts', 'active_mail')
      end
    end
  end
end
