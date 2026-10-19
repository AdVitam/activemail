# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Quality
    module OutputFilter
      class << self
        extend T::Sig

        sig { params(filter: T.untyped).returns(Proc) }
        def coerce(filter)
          return filter if filter.is_a?(Proc)

          pattern, replacement = filter if filter.is_a?(Array) && filter.size == 2
          raise TypeError, "output filter must be a Proc or [Regexp, String], got #{filter.inspect}" unless pattern.is_a?(Regexp) && replacement.is_a?(String)

          ->(content) { content.gsub(pattern, replacement) }
        end
      end
    end
  end
end
