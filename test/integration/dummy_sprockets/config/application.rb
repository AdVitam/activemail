# frozen_string_literal: true

require 'rails'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'sprockets/railtie'
require 'dartsass-sprockets'
require 'activemail'

COMMON = File.expand_path('../../dummy_common', __dir__)

class DummySprockets < Rails::Application
  config.root = File.expand_path('..', __dir__)
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.enable_reloading = false
  config.secret_key_base = 'dummy'
  config.logger = Logger.new(nil)
  config.autoload_paths << File.join(COMMON, 'mailers')
  config.paths['app/views'] << File.join(COMMON, 'views')
  config.action_mailer.delivery_method = :test
  config.assets.compile = ENV['ACTIVEMAIL_PRECOMPILED'] != '1'
  config.assets.cache_store = :memory_store
  config.paths['public'] = ENV.fetch('ACTIVEMAIL_ASSETS_DIR')
end
