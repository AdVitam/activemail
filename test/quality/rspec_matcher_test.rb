# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'activemail/quality/rspec'

# Tests the matcher object directly — no RSpec boot required.
class RspecMatcherTest < QualityTest
  CLEAN = <<~HTML.freeze
    <!DOCTYPE html>
    <html lang="en"><head></head><body>
      <table role="presentation"><tr><td>#{'x ' * 600}</td></tr></table>
    </body></html>
  HTML

  VIOLATING = '<html><body><img src="x.png"></body></html>'

  def matcher(**)
    ActiveMail::Quality::Rspec::ValidEmailMatcher.new(**)
  end

  def test_matches_clean_html
    assert matcher.matches?(CLEAN)
  end

  def test_does_not_match_violating_html
    refute matcher.matches?(VIOLATING)
  end

  def test_failure_message_lists_violations_after_a_failed_match
    m = matcher
    m.matches?(VIOLATING)

    assert_includes m.failure_message, 'img_alt'
  end

  def test_failure_message_when_negated
    assert_kind_of String, matcher.failure_message_when_negated
    refute_empty matcher.failure_message_when_negated
  end

  def test_description
    assert_equal 'be a valid email', matcher.description
  end

  def test_respects_custom_guard
    tiny = ActiveMail::Quality::Guard.new(max_bytes: 10)

    refute matcher(guard: tiny).matches?(CLEAN)
  end

  def test_no_rspec_dependency_is_required
    refute defined?(RSpec), 'RSpec must not be loaded as a gem dependency'
  end
end
