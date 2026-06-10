# typed: false
# frozen_string_literal: true

require 'rails/engine'

module Inky
  module Rails
    class Engine < ::Rails::Engine
      config.annotations.register_extensions('inky') { |annotation| /<!--\s*(#{annotation}):?\s*(.*) -->/ } if config.respond_to?(:annotations)
    end
  end
end
