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
end
