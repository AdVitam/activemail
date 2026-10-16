# typed: strict
# frozen_string_literal: true

require 'pathname'
require 'sorbet-runtime'

module ActiveMail
  module Quality
    # RenderAll deletes inside this directory, so it must provably stay under the host root.
    module OutputDir
      class << self
        extend T::Sig

        sig { params(value: String).returns(String) }
        def validate!(value)
          raise ArgumentError, 'output_dir must not be blank' if value.strip.empty?
          raise ArgumentError, "output_dir must be relative, got #{value.inspect}" if Pathname(value).absolute?

          segments = value.split(%r{[/\\]}).reject(&:empty?)
          raise ArgumentError, "output_dir must not contain '..', got #{value.inspect}" if segments.include?('..')
          raise ArgumentError, "output_dir must not be '.', got #{value.inspect}" if segments.all?('.')

          value
        end

        sig { params(value: String, root: T.any(String, Pathname)).returns(Pathname) }
        def resolve(value, root)
          validate!(value)
          base = Pathname(File.expand_path(root.to_s))
          resolved = Pathname(File.expand_path(value, base.to_s))
          raise ArgumentError, "output_dir #{value.inspect} must resolve strictly under #{base}" unless resolved.to_s.start_with?("#{base}/")

          resolved
        end
      end
    end
  end
end
