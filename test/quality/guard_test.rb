# frozen_string_literal: true

require_relative 'quality_test_helper'

class GuardTest < QualityTest
  CLEAN_DOC = <<~HTML.freeze
    <!DOCTYPE html>
    <html lang="en">
      <head><meta charset="utf-8"></head>
      <body>
        <table role="presentation"><tr><td>#{'padding ' * 200}</td></tr></table>
        <img src="logo.png" alt="Logo">
      </body>
    </html>
  HTML

  def setup
    super
    @guard = ActiveMail::Quality::Guard.new
  end

  def test_rejects_non_positive_thresholds
    assert_raises(ArgumentError) { ActiveMail::Quality::Guard.new(max_bytes: 0) }
    assert_raises(ArgumentError) { ActiveMail::Quality::Guard.new(min_full_doc_bytes: -1) }
  end

  def test_blank_lang_attribute_is_a_violation
    html = %(<html lang="   "><head></head><body>#{'x ' * 600}</body></html>)

    assert_includes rules(html), :lang
  end

  def rules(html)
    @guard.violations(html).map(&:rule)
  end

  def test_clean_document_has_no_violations
    assert_empty @guard.violations(CLEAN_DOC)
    assert @guard.valid?(CLEAN_DOC)
  end

  def test_oversized_html_violates_max_bytes
    guard = ActiveMail::Quality::Guard.new(max_bytes: 100)
    violations = guard.violations(CLEAN_DOC)

    assert_includes violations.map(&:rule), :max_bytes
    refute guard.valid?(CLEAN_DOC)
  end

  def test_under_max_bytes_does_not_violate
    refute_includes rules(CLEAN_DOC), :max_bytes
  end

  def test_table_without_presentation_role_violates
    html = CLEAN_DOC.sub('role="presentation"', '')

    assert_includes rules(html), :table_role
  end

  def test_table_role_check_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: [:table_role])
    html = CLEAN_DOC.sub('role="presentation"', '')

    refute_includes guard.violations(html).map(&:rule), :table_role
  end

  def test_img_without_alt_violates
    html = CLEAN_DOC.sub('alt="Logo"', '')

    assert_includes rules(html), :img_alt
  end

  def test_empty_alt_is_allowed
    html = CLEAN_DOC.sub('alt="Logo"', 'alt=""')

    refute_includes rules(html), :img_alt
  end

  def test_img_alt_check_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: [:img_alt])
    html = CLEAN_DOC.sub('alt="Logo"', '')

    refute_includes guard.violations(html).map(&:rule), :img_alt
  end

  def test_full_doc_missing_lang_violates
    html = CLEAN_DOC.sub('<html lang="en">', '<html>')

    assert_includes rules(html), :lang
  end

  def test_empty_lang_violates
    html = CLEAN_DOC.sub('lang="en"', 'lang=""')

    assert_includes rules(html), :lang
  end

  def test_lang_check_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: [:lang])
    html = CLEAN_DOC.sub('<html lang="en">', '<html>')

    refute_includes guard.violations(html).map(&:rule), :lang
  end

  def test_malformed_html_violates_parse_error
    html = %(<html lang="en"><head></head><body><b><i>oops</b></i>#{'x ' * 600}</body></html>)

    assert_includes rules(html), :parse_error
  end

  def test_unknown_html5_tag_is_not_a_parse_error
    html = %(<html lang="en"><head></head><body><section>#{'x ' * 600}</section></body></html>)

    refute_includes rules(html), :parse_error
  end

  def test_parse_error_check_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: [:parse_error])
    html = '<html lang="en"><body><b><i>oops</b></i></body></html>'

    refute_includes guard.violations(html).map(&:rule), :parse_error
  end

  def test_tiny_full_doc_violates_min_bytes
    html = '<html lang="en"><body>hi</body></html>'

    assert_includes rules(html), :min_full_doc_bytes
  end

  def test_fragment_is_not_subject_to_full_doc_rules
    # No <html>: lang and min_full_doc_bytes must not fire even when tiny.
    fragment = '<table role="presentation"><tr><td>hi</td></tr></table>'
    violations = rules(fragment)

    refute_includes violations, :lang
    refute_includes violations, :min_full_doc_bytes
  end

  def test_fragment_still_checks_table_and_img
    fragment = '<table><tr><td><img src="x.png"></td></tr></table>'
    violations = rules(fragment)

    assert_includes violations, :table_role
    assert_includes violations, :img_alt
  end

  def test_violation_carries_rule_and_message
    violation = @guard.violations('<html lang="en"><body>hi</body></html>').find { |v| v.rule == :lang } ||
                @guard.violations('<table><tr><td>x</td></tr></table>').first

    assert_kind_of Symbol, violation.rule
    assert_kind_of String, violation.message
    refute_empty violation.message
  end
end
