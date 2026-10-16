# typed: strict
# frozen_string_literal: true

require 'fileutils'
require 'pathname'

require_relative '../quality'
require_relative 'output_dir'

module ActiveMail
  module Quality
    # Render + guard every host preview; lives here (not the Rakefile) to stay unit-testable.
    class RenderAll
      extend T::Sig

      class Result < T::Struct
        const :output_root, Pathname
        const :discovered, Integer
        const :rendered, Integer
        const :render_failures, T::Hash[String, String]
        const :guard_failures, T::Hash[String, T::Array[Guard::Violation]]
        const :broken_required, T::Array[String]
      end

      MARKER = '.activemail_previews'
      EXTENSIONS = T.let({ html: 'html', text: 'txt' }.freeze, T::Hash[Symbol, String])

      sig { returns(Pathname) }
      attr_reader :output_root

      sig { params(root: T.any(String, Pathname), config: Configuration).void }
      def initialize(root:, config: ActiveMail::Quality.config)
        @config = T.let(config, Configuration)
        @output_root = T.let(OutputDir.resolve(config.output_dir, root), Pathname)
        @render_failures = T.let({}, T::Hash[String, String])
        @guard_failures = T.let({}, T::Hash[String, T::Array[Guard::Violation]])
        @failed_keys = T.let(Set.new, T::Set[String])
        @rendered = T.let(0, Integer)
      end

      sig { returns(Result) }
      def call
        clean_previous_output
        previews = PreviewRenderer.all
        PreviewRenderer.cases(@config, previews).each { |preview, email, locale| render_locale(preview, email, locale) }

        Result.new(
          output_root: @output_root, discovered: previews.size, rendered: @rendered, render_failures: @render_failures,
          guard_failures: @guard_failures, broken_required: broken_required(previews)
        )
      end

      private

      sig { void }
      def clean_previous_output
        ensure_owned!
        @output_root.glob('**/*.{html,txt}').each { |path| path.delete if path.file? }
        prune_empty_directories
        FileUtils.mkdir_p(@output_root)
        FileUtils.touch(@output_root.join(MARKER))
      end

      # The marker proves a previous run owns the directory: without it, an existing
      # non-empty output_dir (public/, app/...) is never touched.
      sig { void }
      def ensure_owned!
        return if !@output_root.exist? || @output_root.join(MARKER).exist? || @output_root.empty?

        raise ArgumentError, "output_dir #{@output_root} is not empty and was not created by activemail (no #{MARKER}); use a dedicated directory"
      end

      sig { void }
      def prune_empty_directories
        @output_root.glob('**/*/').sort_by { |dir| -dir.to_s.size }.each { |dir| dir.rmdir if dir.empty? }
      end

      # A required preview that fails, OR is never discovered at all (typo / deleted), is broken.
      sig { params(previews: T::Array[[T.untyped, String]]).returns(T::Array[String]) }
      def broken_required(previews)
        required = @config.required_previews
        discovered = previews.map { |preview, email| PreviewRenderer.key(preview, email) }
        (@failed_keys.to_a & required) | (required - discovered)
      end

      sig { params(preview: T.untyped, email: String, locale: Symbol).void }
      def render_locale(preview, email, locale)
        key = PreviewRenderer.key(preview, email)
        label = locale == I18n.default_locale ? key : "#{key} [#{locale}]"
        violations = render_one(preview, email, locale, label)
        record(key, label, violations)
      end

      sig { params(key: String, label: String, violations: T.nilable(T::Array[Guard::Violation])).void }
      def record(key, label, violations)
        return @failed_keys << key if violations.nil?

        @rendered += 1
        return if violations.empty?

        @failed_keys << key
        @guard_failures[label] = violations
      end

      sig { params(preview: T.untyped, email: String, locale: Symbol, label: String).returns(T.nilable(T::Array[Guard::Violation])) }
      def render_one(preview, email, locale, label)
        PreviewRenderer.within(preview, email, locale, @config.around_each) do |mail|
          next [] if PreviewRenderer.declined?(mail)

          write(preview, email, locale, mail)
          @config.guard.violations(mail)
        end
      rescue SystemCallError
        raise # disk/permission failures are not template bugs — let them abort the run
      rescue StandardError => e
        @render_failures[label] = describe(e)
        nil
      end

      sig { params(error: StandardError).returns(String) }
      def describe(error)
        root = error.cause
        cause = root ? "\n  caused by: #{root.class}: #{root.message}" : ''
        "#{error.class}: #{error.message}\n  #{error.backtrace&.first(5)&.join("\n  ")}#{cause}"
      end

      sig { params(preview: T.untyped, email: String, locale: Symbol, mail: T.untyped).void }
      def write(preview, email, locale, mail)
        dir = @output_root.join(preview.preview_name)
        FileUtils.mkdir_p(dir)
        # The default locale stays unsuffixed so a diff against an older run still lines up.
        stem = locale == I18n.default_locale ? email : "#{email}.#{locale}"
        contents = { html: PreviewRenderer.html_body(mail), text: PreviewRenderer.text_body(mail) }

        @config.formats.each do |format|
          File.write(dir.join("#{stem}.#{EXTENSIONS.fetch(format)}"), filtered(contents.fetch(format)))
        end
      end

      sig { params(content: String).returns(String) }
      def filtered(content)
        @config.output_filters.reduce(content) { |acc, filter| filter.call(acc) }
      end
    end
  end
end
