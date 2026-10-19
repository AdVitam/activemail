# frozen_string_literal: true

require 'test_helper'

class PremailerInlinerTest < ActiveMailTest
  # Counts only the scratch parser the cache uses on a miss, not the replaying CachedParser.
  module ParseCounter
    class << self
      attr_accessor :count
    end

    def add_block!(...)
      ParseCounter.count += 1 if instance_of?(::CssParser::Parser)
      super
    end
  end

  STYLE = '<style>p{color:red}.a{margin:0 auto}@media (max-width:480px){p{color:blue}}</style>'

  def setup
    super
    ActiveMail::Inliner::Premailer.new.inline('<p>warm</p>')
    ::CssParser::Parser.prepend(ParseCounter) unless ::CssParser::Parser < ParseCounter
    ParseCounter.count = 0
    document.rule_sets.clear
  end

  def test_inlines_style_into_attribute
    output = ActiveMail::Inliner::Premailer.new.inline('<style>p{color:red}</style><p>x</p>')

    assert_match(/<p[^>]*style="[^"]*color:\s*red/i, output)
  end

  def test_parses_the_stylesheet_once_for_many_renders
    inliner = ActiveMail::Inliner::Premailer.new
    5.times { |i| inliner.inline("#{STYLE}<p class=\"a\">#{i}</p>") }

    assert_equal 1, ParseCounter.count
    assert_equal 1, document.rule_sets.size
  end

  def test_a_different_stylesheet_is_parsed_separately
    inliner = ActiveMail::Inliner::Premailer.new
    inliner.inline("#{STYLE}<p>a</p>")
    inliner.inline('<style>p{color:green}</style><p>b</p>')

    assert_equal 2, ParseCounter.count
  end

  def test_output_matches_a_plain_premailer_run
    html = "<html><head>#{STYLE}</head><body><p class=\"a\">Hi</p><a href=\"/x\" style=\"color:#fff\">link</a></body></html>"
    plain = ::Premailer.new(html, with_html_string: true, warn_level: ::Premailer::Warnings::NONE).to_inline_css
    inliner = ActiveMail::Inliner::Premailer.new

    assert_equal plain, inliner.inline(html)
    assert_equal plain, inliner.inline(html)
  end

  def test_cache_is_bounded
    inliner = ActiveMail::Inliner::Premailer.new
    (ActiveMail::Inliner::Premailer::Document::RuleSetCache::LIMIT + 4).times { |i| inliner.inline("<style>p{width:#{i}px}</style><p>x</p>") }

    assert_equal ActiveMail::Inliner::Premailer::Document::RuleSetCache::LIMIT, document.rule_sets.size
  end

  private

  def document
    ActiveMail::Inliner::Premailer::Document
  end
end
