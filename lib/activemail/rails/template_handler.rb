# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Rails
    class TemplateHandler
      extend T::Sig

      sig { params(compose_with: T.nilable(T.any(String, Symbol))).void }
      def initialize(compose_with = nil)
        # ActionView handlers share no interface (Procs, objects, classes).
        @engine_handler = T.let(nil, T.untyped)
        return unless compose_with

        # Without this guard a typo would silently fall back to the configured
        # template_engine in #engine_handler.
        @engine_handler = ActionView::Template.registered_template_handler(compose_with) ||
                          raise(ArgumentError, "No template handler found for #{compose_with}")
      end

      sig { returns(T.untyped) }
      def engine_handler
        return @engine_handler if @engine_handler

        type = ::ActiveMail.configuration.template_engine
        ActionView::Template.registered_template_handler(type) ||
          raise("No template handler found for #{type}")
      end

      sig { params(template: T.untyped, source: T.nilable(String)).returns(String) }
      def call(template, source = nil)
        compiled_source =
          if source
            engine_handler.call(template, source)
          else
            engine_handler.call(template)
          end
        "ActiveMail::Core.new.transpile(begin; #{compiled_source};end)"
      end

      module Composer
        extend T::Sig

        sig { params(ext: T.untyped, args: T.untyped).returns(T.untyped) }
        def register_template_handler(ext, *args)
          super
          super(:"inky-#{ext}", ActiveMail::Rails::TemplateHandler.new(ext))
        end
      end
    end
  end
end

ActiveSupport.on_load(:action_view) do
  ActionView::Template.template_handler_extensions.each do |ext|
    ActionView::Template.register_template_handler :"inky-#{ext}", ActiveMail::Rails::TemplateHandler.new(ext)
  end
  ActionView::Template.register_template_handler :inky, ActiveMail::Rails::TemplateHandler.new
  ActionView::Template.singleton_class.send :prepend, ActiveMail::Rails::TemplateHandler::Composer
end
