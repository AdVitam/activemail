# frozen_string_literal: true

require 'rails/generators'

module ActiveMail
  module Generators
    # Ejects the framework SCSS partials into the host app, where they shadow the
    # gem's copies (same `active_mail/` import path) and can be customized.
    class StylesGenerator < ::Rails::Generators::Base
      desc 'Copy ActiveMail framework SCSS partials into the host app for customization'
      source_root File.expand_path('../../../app/assets/stylesheets/active_mail', __dir__)

      TARGET_DIR = File.join('app', 'assets', 'stylesheets', 'active_mail')

      # The .scss.erb token bridge is deliberately not ejected: it needs ERB
      # preprocessing, and tokens come from Ruby config (rake active_mail:tokens:export).
      def copy_styles
        Dir.children(self.class.source_root).each do |name|
          next if name.end_with?('.erb')

          copy_file name, File.join(TARGET_DIR, name)
        end
      end

      def show_readme
        say "\nEjected the ActiveMail SCSS partials to #{TARGET_DIR}.", :green
        say 'Token values come from Ruby (config.tokens.color/font/spacing). For a static'
        say 'SCSS partial of those values, run `rake active_mail:tokens:export`.'
      end
    end
  end
end
