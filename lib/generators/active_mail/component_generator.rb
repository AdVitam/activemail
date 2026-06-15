# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/named_base'

module ActiveMail
  module Generators
    class ComponentGenerator < ::Rails::Generators::NamedBase
      desc 'Scaffold an ActiveMail component class (rails g active_mail:component Cta)'
      source_root File.join(File.dirname(__FILE__), 'templates')

      def create_component
        template 'component.rb.tt', File.join('app', 'mailers', 'components', "#{file_name}.rb")
      end

      def show_register_snippet
        say "\nRegister the component in config/initializers/active_mail.rb:", :green
        say %(  config.register_component "#{tag_name}", Components::#{class_name})
        say "\nThen use <#{tag_name}>…</#{tag_name}> in your ActiveMail views.\n"
      end

      private

      # Tag = kebab-cased class name, matching the gem's component naming.
      def tag_name
        file_name.tr('_', '-')
      end
    end
  end
end
