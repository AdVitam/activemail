# frozen_string_literal: true

source 'https://rubygems.org'

# Specify the gem's runtime dependencies in activemail.gemspec
gemspec

gem 'minitest', '~> 5.20'
gem 'rails', ENV.fetch('RAILS_VERSION', '>= 7.1')
gem 'rake', '~> 13.0'
gem 'rubocop', '~> 1.60', require: false
gem 'sorbet', '>= 0.5', require: false
gem 'sorbet-static-and-runtime', '>= 0.5', require: false
gem 'tapioca', '>= 0.13', require: false

group :test do
  gem 'roadie', '>= 5.0', require: false
end
