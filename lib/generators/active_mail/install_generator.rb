# frozen_string_literal: true

require 'rails/generators'

module ActiveMail
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      desc 'Install ActiveMail: initializer and a mailer layout'
      source_root File.join(File.dirname(__FILE__), 'templates')
      argument :layout_name, type: :string, default: 'mailer', banner: 'layout_name'

      class_option :haml, desc: 'Generate the layout in Haml', type: :boolean
      class_option :slim, desc: 'Generate the layout in Slim', type: :boolean

      def create_initializer
        template 'initializer.rb', File.join('config', 'initializers', 'active_mail.rb')
      end

      # A plain mailer.html.erb would win over the generated inky layout; keep it.
      def preserve_original_mailer_layout
        return unless layout_name == 'mailer' && extension == 'erb'

        original = File.join(layouts_base_dir, 'mailer.html.erb')
        back_up_layout(original) if File.exist?(File.join(destination_root, original))
      end

      def create_mailer_layout
        template "mailer_layout.html.inky-#{extension}",
                 File.join(layouts_base_dir, "#{layout_name.underscore}.html.inky-#{extension}")
      end

      def show_readme
        say "\nActiveMail installed.", :green
        say '  • config/initializers/active_mail.rb — configure tokens, inliner, components.'
        say "  • app/views/layouts/#{layout_name.underscore}.html.inky-#{extension} — your mailer layout."
        say "\nPoint your mailers at the layout, e.g. `layout \"#{layout_name.underscore}\"`, and"
        say "name views *.html.inky-#{extension} to enable ActiveMail markup."
        say "\nCustomize styling via Ruby tokens in the initializer (config.tokens.color/font/spacing),"
        say 'or run `rails g active_mail:styles` to eject and edit the SCSS partials.'
      end

      private

      def back_up_layout(original)
        backup = File.join(layouts_base_dir, "old_mailer_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.html.erb")
        File.rename(File.join(destination_root, original), File.join(destination_root, backup))
        say "Renamed existing #{original} → #{backup} (it would shadow the new ActiveMail layout).", :yellow
      end

      def layouts_base_dir
        File.join('app', 'views', 'layouts')
      end

      def extension
        %w[haml slim].find { |ext| options.send(ext) } || 'erb'
      end
    end
  end
end
