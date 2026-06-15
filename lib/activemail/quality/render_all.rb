# typed: strict
# frozen_string_literal: true

require 'fileutils'

require_relative '../quality'

module ActiveMail
  module Quality
    # Render + guard every host preview; lives here (not the Rakefile) to stay unit-testable.
    class RenderAll
      extend T::Sig

      class Result < T::Struct
        const :discovered, Integer
        const :rendered, Integer
        const :render_failures, T::Hash[String, String]
        const :guard_failures, T::Hash[String, T::Array[Guard::Violation]]
        const :broken_required, T::Array[String]
      end

      sig { params(output_root: T.any(String, Pathname), config: Configuration).void }
      def initialize(output_root:, config: ActiveMail::Quality.config)
        @output_root = T.let(Pathname(output_root), Pathname)
        @config = T.let(config, Configuration)
      end

      sig { returns(Result) }
      def call
        FileUtils.rm_rf(@output_root)
        FileUtils.mkdir_p(@output_root)

        render_failures = {}
        guard_failures = {}
        previews = PreviewRenderer.all
        rendered = render_all(previews, render_failures, guard_failures)

        Result.new(
          discovered: previews.size, rendered: rendered, render_failures: render_failures,
          guard_failures: guard_failures, broken_required: broken_required(previews, render_failures, guard_failures)
        )
      end

      private

      # A required preview that fails, OR is never discovered at all (typo / deleted), is broken.
      sig do
        params(
          previews: T::Array[[T.untyped, String]],
          render_failures: T::Hash[String, String],
          guard_failures: T::Hash[String, T::Array[Guard::Violation]]
        ).returns(T::Array[String])
      end
      def broken_required(previews, render_failures, guard_failures)
        required = @config.required_previews
        discovered = previews.map { |preview, email| PreviewRenderer.key(preview, email) }
        ((render_failures.keys | guard_failures.keys) & required) | (required - discovered)
      end

      sig do
        params(previews: T::Array[[T.untyped, String]], render_failures: T::Hash[String, String], guard_failures: T::Hash[String, T::Array[Guard::Violation]]).returns(Integer)
      end
      def render_all(previews, render_failures, guard_failures)
        previews.count do |preview, email|
          key = PreviewRenderer.key(preview, email)
          path = render_one(preview, email, render_failures, key)
          next false unless path

          violations = @config.guard.violations(File.read(path))
          guard_failures[key] = violations unless violations.empty?
          true
        end
      end

      sig do
        params(preview: T.untyped, email: String, failures: T::Hash[String, String], key: String).returns(T.nilable(Pathname))
      end
      def render_one(preview, email, failures, key)
        PreviewRenderer.render_to_disk(preview, email, @output_root)
      rescue SystemCallError
        raise # disk/permission failures are not template bugs — let them abort the run
      rescue StandardError => e
        root = e.cause
        cause = root ? "\n  caused by: #{root.class}: #{root.message}" : ''
        failures[key] = "#{e.class}: #{e.message}\n  #{e.backtrace&.first(5)&.join("\n  ")}#{cause}"
        nil
      end
    end
  end
end
