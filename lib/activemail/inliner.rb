# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'inliner/base'
require_relative 'inliner/premailer'
require_relative 'inliner/roadie'
require_relative 'inliner/null'

module ActiveMail
  module Inliner
    extend T::Sig

    ADAPTERS = T.let(
      { premailer: Premailer, roadie: Roadie, null: Null }.freeze,
      T::Hash[Symbol, T.class_of(Base)]
    )

    Setting = T.type_alias { T.any(Symbol, Base, T.class_of(Base)) }

    sig { params(setting: Setting).returns(Base) }
    def self.resolve(setting)
      return setting if setting.is_a?(Base)
      return setting.new if setting.is_a?(Class) && setting < Base

      adapter = ADAPTERS[setting] if setting.is_a?(Symbol)
      return adapter.new if adapter

      raise ArgumentError, "unknown inliner #{setting.inspect}, expected one of #{ADAPTERS.keys.inspect}, an Inliner::Base subclass, or an instance"
    end
  end
end
