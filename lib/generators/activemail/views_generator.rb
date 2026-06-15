# frozen_string_literal: true

require 'rails/generators'

module ActiveMail
  module Generators
    class ViewsGenerator < ::Rails::Generators::Base
      desc 'Copy ActiveMail default layout views into the host app for customization'
      source_root File.expand_path('../../../app/views/layouts/activemail', __dir__)

      def copy_views
        directory '.', File.join('app', 'views', 'layouts', 'activemail')
      end
    end
  end
end
