# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'mail'

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

  def test_rejects_unknown_disable_rule
    assert_raises(ArgumentError) { ActiveMail::Quality::Guard.new(disable: [:nope]) }
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

  def test_translation_missing_text_violates
    html = CLEAN_DOC.sub('padding', 'translation missing: en.hello')

    assert_includes rules(html), :translation_missing
  end

  def test_translation_missing_class_violates
    html = CLEAN_DOC.sub('<img', '<span class="translation_missing" title="x">Hello</span><img')

    assert_includes rules(html), :translation_missing
  end

  def test_clean_document_has_no_translation_missing
    refute_includes rules(CLEAN_DOC), :translation_missing
  end

  def test_two_html_roots_violate_single_root
    html = "#{CLEAN_DOC}<html lang=\"en\"><body>again</body></html>"

    assert_includes rules(html), :single_root
  end

  def test_two_body_roots_violate_single_root
    html = CLEAN_DOC.sub('</body>', '<body>nested</body></body>')

    assert_includes rules(html), :single_root
  end

  def test_single_root_passes_on_clean_document
    refute_includes rules(CLEAN_DOC), :single_root
  end

  def test_message_rules_are_skipped_for_a_plain_html_string
    refute_includes rules(CLEAN_DOC), :text_part_present
  end

  def test_multipart_message_with_plain_text_has_no_violations
    assert_empty @guard.violations(build_mail(text: 'Hello there'))
  end

  def test_message_without_text_part_violates_text_part_present
    assert_includes message_rules(build_mail(text: nil)), :text_part_present
  end

  def test_blank_text_part_violates_text_part_present
    assert_includes message_rules(build_mail(text: '  ')), :text_part_present
  end

  def test_text_part_with_markup_violates_text_part_plain
    assert_includes message_rules(build_mail(text: 'Hi <br> there')), :text_part_plain
  end

  def test_plain_text_with_angle_brackets_is_not_markup
    refute_includes message_rules(build_mail(text: 'if a < b and c > d')), :text_part_plain
  end

  def test_translation_missing_in_subject_or_text_violates
    assert_includes message_rules(build_mail(text: 'translation missing: en.x')), :translation_missing_text
    assert_includes message_rules(build_mail(text: 'ok', subject: 'translation missing: en.s')), :translation_missing_text
  end

  def test_message_without_html_violates_html_part_present_and_still_gets_message_rules
    mail = Mail.new do
      content_type 'text/plain; charset=UTF-8'
      body 'only text'
    end
    found = message_rules(mail)

    assert_includes found, :html_part_present
    assert_includes found, :text_part_present
  end

  def test_declined_send_has_nothing_to_check
    assert_empty @guard.violations(Mail.new)
    assert_empty @guard.violations(Class.new { def self.name = 'ActionMailer::Base::NullMail' }.new)
  end

  def test_html_part_present_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: %i[html_part_present text_part_present])
    mail = Mail.new do
      content_type 'text/plain; charset=UTF-8'
      body 'only text'
    end

    assert_empty guard.violations(mail)
  end

  def test_violation_to_s_formats_rule_and_message
    violation = ActiveMail::Quality::Guard::Violation.new(rule: :img_alt, message: 'bad')

    assert_equal '[img_alt] bad', violation.to_s
  end

  def test_message_html_rules_run_on_the_html_part
    assert_includes message_rules(build_mail(text: 'ok', html: CLEAN_DOC.sub('alt="Logo"', ''))), :img_alt
  end

  def test_message_rules_can_be_disabled
    guard = ActiveMail::Quality::Guard.new(disable: %i[text_part_present text_part_plain])

    assert_empty guard.violations(build_mail(text: nil))
  end

  def test_custom_html_rule
    rule = ActiveMail::Quality::Rule.html(:no_justify) do |_doc, html|
      'justified text' if html.include?('justify')
    end
    guard = ActiveMail::Quality::Guard.new(rules: [rule])
    violations = guard.violations(CLEAN_DOC.sub('padding', 'text-align: justify'))

    assert_equal [:no_justify], violations.map(&:rule)
    assert_equal 'justified text', violations.first.message
    assert_empty guard.violations(CLEAN_DOC)
  end

  def test_custom_html_rule_receives_the_parsed_document
    rule = ActiveMail::Quality::Rule.html(:one_logo) { |doc, _html| 'no logo' unless doc.at_css('img[src="logo.png"]') }
    guard = ActiveMail::Quality::Guard.new(rules: [rule])

    assert_empty guard.violations(CLEAN_DOC)
    assert_equal [:one_logo], guard.violations(CLEAN_DOC.sub('logo.png', 'other.png')).map(&:rule)
  end

  def test_custom_rule_can_report_several_messages
    rule = ActiveMail::Quality::Rule.html(:many) { |_doc, _html| %w[a b] }
    violations = ActiveMail::Quality::Guard.new(rules: [rule]).violations(CLEAN_DOC)

    assert_equal %w[a b], violations.map(&:message)
  end

  def test_custom_message_rule_receives_the_mail
    rule = ActiveMail::Quality::Rule.message(:subject_set) { |mail| 'missing subject' if mail.subject.to_s.empty? }
    guard = ActiveMail::Quality::Guard.new(rules: [rule])

    assert_includes guard.violations(build_mail(text: 'ok', subject: '')).map(&:rule), :subject_set
    assert_empty guard.violations(build_mail(text: 'ok', subject: 'Hello'))
  end

  def test_rejects_a_custom_rule_reusing_a_builtin_name
    rule = ActiveMail::Quality::Rule.html(:img_alt) { |_doc, _html| nil }

    assert_raises(ArgumentError) { ActiveMail::Quality::Guard.new(rules: [rule]) }
  end

  def test_rejects_unknown_rule_level
    assert_raises(ArgumentError) { ActiveMail::Quality::Rule.new(:x, :other, proc {}) }
  end

  def test_html_is_parsed_once_per_check
    parses = 0
    counting = Nokogiri.method(:HTML)
    rule = ActiveMail::Quality::Rule.html(:noop) { |_doc, _html| nil }
    guard = ActiveMail::Quality::Guard.new(rules: [rule])

    Nokogiri.stub(:HTML, lambda { |*args|
      parses += 1
      counting.call(*args)
    }) { guard.violations(CLEAN_DOC) }

    assert_equal 1, parses
  end

  private

  def message_rules(mail)
    @guard.violations(mail).map(&:rule)
  end

  def build_mail(text:, html: CLEAN_DOC, subject: 'Hello')
    html_body = html
    text_body = text
    Mail.new do
      subject subject
      text_part { body text_body } if text_body
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html_body
      end
    end
  end
end
