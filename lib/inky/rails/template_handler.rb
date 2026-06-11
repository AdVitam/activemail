# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module Inky
  module Rails
    class TemplateHandler
      extend T::Sig

      sig { params(compose_with: T.nilable(T.any(String, Symbol))).void }
      def initialize(compose_with = nil)
        # ActionView handlers share no interface (Procs, objects, classes).
        @engine_handler = T.let(
          compose_with ? ActionView::Template.registered_template_handler(compose_with) : nil,
          T.untyped
        )
      end

      sig { returns(T.untyped) }
      def engine_handler
        return @engine_handler if @engine_handler

        type = ::Inky.configuration.template_engine
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
        "Inky::Core.new.release_the_kraken(begin; #{compiled_source};end)"
      end

      module Composer
        extend T::Sig

        sig { params(ext: T.untyped, args: T.untyped).returns(T.untyped) }
        def register_template_handler(ext, *args)
          super
          super(:"inky-#{ext}", Inky::Rails::TemplateHandler.new(ext))
        end
      end
    end
  end
end

ActiveSupport.on_load(:action_view) do
  ActionView::Template.template_handler_extensions.each do |ext|
    ActionView::Template.register_template_handler :"inky-#{ext}", Inky::Rails::TemplateHandler.new(ext)
  end
  ActionView::Template.register_template_handler :inky, Inky::Rails::TemplateHandler.new
  ActionView::Template.singleton_class.send :prepend, Inky::Rails::TemplateHandler::Composer
end
