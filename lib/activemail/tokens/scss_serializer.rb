# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  class Tokens
    # !default lets a host pre-declare overrides upstream. Values are emitted
    # verbatim (trusted, app-controlled input) — not escaped.
    module ScssSerializer
      extend T::Sig

      sig { params(stores: T::Hash[Symbol, TokenMap]).returns(String) }
      def self.call(stores)
        lines = stores.flat_map do |group, store|
          store.map { |name, value| "$am-#{group}-#{name.to_s.tr('_', '-')}: #{value} !default;" }
        end
        "#{lines.join("\n")}\n"
      end
    end
  end
end
