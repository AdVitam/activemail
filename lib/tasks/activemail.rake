# frozen_string_literal: true

require 'activemail'
require 'fileutils'

namespace :activemail do
  namespace :tokens do
    desc 'Export design tokens to a static SCSS partial (for Propshaft apps that cannot preprocess .scss.erb)'
    # :environment so the host initializer's config.tokens overrides are loaded.
    task :export, [:path] => :environment do |_task, args|
      path = args[:path] || 'app/assets/stylesheets/activemail/_activemail_tokens.scss'
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, ActiveMail.scss_variables)
      puts "Wrote #{ActiveMail.tokens.colors.size + ActiveMail.tokens.fonts.size + ActiveMail.tokens.spacings.size} tokens to #{path}"
    end
  end

  namespace :emails do
    desc 'Render every host mailer preview to disk and run the quality guard on each'
    task render_all: :environment do
      require 'activemail/quality/render_all'

      config = ActiveMail::Quality.config
      output_root = defined?(Rails) && Rails.respond_to?(:root) ? Rails.root.join(config.output_dir) : Pathname(config.output_dir)
      result = ActiveMail::Quality::RenderAll.new(output_root: output_root, config: config).call
      puts "Rendered #{result.rendered} email(s) into #{output_root}"
      # A green run on zero previews would silently verify nothing — make it visible.
      warn '[activemail] WARNING: no mailer previews were discovered — nothing was checked.' if result.discovered.zero?
      result.render_failures.each { |key, error| puts "  render failed: #{key}: #{error}" }
      result.guard_failures.each do |key, violations|
        puts "  guard failed: #{key}", violations.map { |v| "    - [#{v.rule}] #{v.message}" }.join("\n")
      end
      abort "\n#{result.broken_required.size} required preview(s) failed: #{result.broken_required.join(', ')}" if result.broken_required.any?
    end
  end
end
