# frozen_string_literal: true

require 'active_mail'

namespace :active_mail do
  namespace :tokens do
    desc 'Export design tokens to a static SCSS partial (for Propshaft apps that cannot preprocess .scss.erb)'
    task :export, [:path] do |_task, args|
      path = args[:path] || 'app/assets/stylesheets/active_mail/_active_mail_tokens.scss'
      File.write(path, ActiveMail.tokens.to_scss)
      puts "Wrote #{ActiveMail.tokens.colors.size + ActiveMail.tokens.fonts.size + ActiveMail.tokens.spacings.size} tokens to #{path}"
    end
  end

  namespace :emails do
    desc 'Render every host mailer preview to disk and run the quality guard on each'
    task render_all: :environment do
      require 'active_mail/quality/render_all'

      config = ActiveMail::Quality.config
      output_root = defined?(Rails) ? Rails.root.join(config.output_dir) : Pathname(config.output_dir)
      result = ActiveMail::Quality::RenderAll.new(output_root: output_root, config: config).call

      puts "Rendered #{result.rendered} email(s) into #{output_root}"
      # A green run on zero previews would silently verify nothing — make it visible.
      warn '[activemail] WARNING: no mailer previews were discovered — nothing was checked.' if result.discovered.zero?
      result.render_failures.each { |key, error| puts "  render failed: #{key}: #{error}" }
      result.guard_failures.each do |key, violations|
        puts "  guard failed: #{key}"
        violations.each { |v| puts "    - [#{v.rule}] #{v.message}" }
      end

      abort "\n#{result.broken_required.size} required preview(s) failed: #{result.broken_required.join(', ')}" if result.broken_required.any?
    end
  end
end
