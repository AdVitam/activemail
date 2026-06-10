# frozen_string_literal: true

require 'rails/generators'

module Inky
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      desc 'Install an Inky mailer layout'
      source_root File.join(File.dirname(__FILE__), 'templates')
      argument :layout_name, type: :string, default: 'mailer', banner: 'layout_name'

      class_option :haml, desc: 'Generate layout in Haml', type: :boolean
      class_option :slim, desc: 'Generate layout in Slim', type: :boolean

      def preserve_original_mailer_layout
        return unless layout_name == 'mailer' && extension == 'erb'

        original_mailer = File.join(layouts_base_dir, 'mailer.html.erb')
        rename_filename = File.join(layouts_base_dir, "old_mailer_#{Time.now.to_i}.html.erb")
        File.rename(original_mailer, rename_filename) if File.exist? original_mailer
      end

      def create_mailer_layout
        template "mailer_layout.html.#{extension}", File.join(layouts_base_dir, "#{layout_name.underscore}.html.#{extension}")
      end

      private

      def layouts_base_dir
        File.join('app', 'views', 'layouts')
      end

      def extension
        %w[haml slim].each do |ext|
          return ext if options.send(ext)
        end
        'erb'
      end
    end
  end
end
