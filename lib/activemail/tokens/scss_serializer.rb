# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  class Tokens
    # !default lets a host configure overrides upstream. Values are emitted
    # verbatim (trusted, app-controlled input) — not escaped; nil becomes Sass null.
    module ScssSerializer
      extend T::Sig

      sig { params(stores: T::Hash[Symbol, T::Hash[Symbol, T.nilable(String)]]).returns(String) }
      def self.call(stores)
        lines = stores.flat_map do |group, store|
          store.map { |name, value| "$am-#{group}-#{name.to_s.tr('_', '-')}: #{value || 'null'} !default;" }
        end
        "#{lines.join("\n")}\n"
      end
    end
  end
end
