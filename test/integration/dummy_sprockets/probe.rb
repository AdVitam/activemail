# frozen_string_literal: true

require_relative 'config/application'

if ENV['ACTIVEMAIL_PRECOMPILE_ONLY'] == '1'
  Rails.application.initialize!
  Rails.application.assets_manifest.compile(Rails.application.config.assets.precompile)
  puts 'PROBE_JSON:{}'
else
  require_relative '../dummy_common/probe'
end
