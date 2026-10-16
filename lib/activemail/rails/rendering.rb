# typed: false
# frozen_string_literal: true

require 'active_support/isolated_execution_state'

module ActiveMail
  module Rails
    # One transpile + inline pass per mailer body. Inky template handlers only
    # mark the scope opened by ActionMailer::Base#render_to_body; the pipeline runs
    # once at its exit, so layouts wrapping a view never re-transpile it.
    module Rendering
      STATE_KEY = :activemail_render_scope

      class Scope
        attr_accessor :inky_html
      end

      class << self
        def scoped
          return yield if current

          scope = Scope.new
          ActiveSupport::IsolatedExecutionState[STATE_KEY] = scope
          body = yield
          scope.inky_html ? ActiveMail::Pipeline.call(body.to_s).html_safe : body
        ensure
          ActiveSupport::IsolatedExecutionState[STATE_KEY] = nil if scope
        end

        def process(output, format)
          scope = current
          return ActiveMail.configuration.core.transpile(output) unless scope

          scope.inky_html = true if format.nil? || format == :html
          output
        end

        private

        def current
          ActiveSupport::IsolatedExecutionState[STATE_KEY]
        end
      end

      module MailerExtension
        def render_to_body(options = {})
          ActiveMail::Rails::Rendering.scoped { super }
        end
      end
    end
  end
end
