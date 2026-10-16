# frozen_string_literal: true

require 'bundler'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Sprockets and Propshaft cannot share a process, so each dummy app boots in its own.
module DummyRunner
  ROOT = File.expand_path('../../..', __dir__)

  module_function

  def run(dummy, env = {})
    probe = File.join(ROOT, 'test', 'integration', dummy, 'probe.rb')
    full_env = { 'BUNDLE_GEMFILE' => Bundler.default_gemfile.to_s, 'RAILS_ENV' => 'test' }.merge(env)
    stdout, stderr, status = Open3.capture3(full_env, RbConfig.ruby, '-rbundler/setup', "-I#{File.join(ROOT, 'lib')}", probe, chdir: ROOT)
    raise "#{dummy} probe failed (#{status.exitstatus}):\n#{stderr}\n#{stdout}" unless status.success?

    JSON.parse(stdout[/^PROBE_JSON:(.*)$/, 1])
  end
end

# Behaviours every pipeline must exhibit, whatever serves the stylesheets.
module DummyAppAssertions
  WELCOME_MARKER = %r{<p class="am-host-marker" style='[^']*font-family[^']*color: #123456;?'>host</p>}

  def assert_inlined_single_pass_mail(result)
    assert result['booted']
    welcome = result.fetch('welcome')

    refute welcome.key?('error'), welcome.inspect

    assert_match WELCOME_MARKER, welcome['html'], 'framework and host CSS must be inlined'
    assert_includes welcome['html'], '<table class="button"'
    assert_equal 1, welcome['html'].scan('<button').size, 'only the <raw> button must stay a literal <button>'
    assert_includes welcome['html'], '<button href="#">x</button>'
    assert_equal 1, welcome['transpile_calls']
    assert_equal "Hello text\n", welcome['text']
    assert_equal '<style>.a{color:red}</style><p class="a">x</p>', welcome['attachment']
  end

  def assert_untouched_and_failing_cases(result)
    assert_equal %(<style>.x{color:red}</style><p class="x">hi</p><button href="#">x</button>\n), result['plain']
    assert_equal 'ActionView::Template::Error', result['missing_stylesheet']['error']
    assert_includes result['missing_stylesheet']['message'], 'nope/nope.css'
    assert(result['annotation_extensions'].any? { |pattern| pattern.include?('inky-erb') })
  end
end
