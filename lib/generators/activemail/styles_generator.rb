# frozen_string_literal: true

require 'rails/generators'

module ActiveMail
  module Generators
    class StylesGenerator < ::Rails::Generators::Base
      desc 'Copy ActiveMail framework SCSS partials into the host app for customization'
      source_root File.expand_path('../../../app/assets/stylesheets/activemail', __dir__)

      TARGET_DIR = File.join('app', 'assets', 'stylesheets', 'activemail')

      # The .scss.erb token bridge is deliberately not ejected: it needs ERB
      # preprocessing, and tokens come from Ruby config (rake activemail:tokens:export).
      def copy_styles
        Dir.children(self.class.source_root).each do |name|
          next if name.end_with?('.erb')

          copy_file name, File.join(TARGET_DIR, name)
        end
      end

      def show_readme
        say "\nEjected the ActiveMail SCSS partials to #{TARGET_DIR}.", :green
        say 'Token values come from Ruby (config.tokens.color/font/spacing). For a static'
        say 'SCSS partial of those values, run `rake activemail:tokens:export`.'
      end
    end
  end
end
