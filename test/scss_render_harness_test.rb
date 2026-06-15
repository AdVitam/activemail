# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'support/scss_compiler'
require 'fileutils'
require 'tmpdir'
# ActionView 7.1 references URI without requiring it (NameError on Ruby 3.3+ outside a full Rails app).
require 'uri'
require 'action_view'
require 'action_view/base'
require 'activemail/rails/template_handler'
require 'activemail/rails/compiled_stylesheet'
require File.expand_path('../app/helpers/activemail/styles_helper', __dir__)

# Render-validation harness: compiles the shipped framework SCSS and validates the
# *rendered + inlined* output, so the styling/inlining regressions (gutter
# overflow, dead collapse selector, container_width divergence, un-inlined
# framework CSS) can't recur. The structural ScssFrameworkTest guards the source;
# this one proves the compiled CSS behaves once rendered through Premailer.
class ScssRenderHarnessTest < ActiveMailTest
  ENGINE_VIEWS = File.expand_path('../app/views', __dir__)
  SAMPLE = '<row><columns large="6">A</columns>' \
           '<columns large="6">B</columns></row>'

  def setup
    super
    @css = ScssCompiler.compile
  end

  # (a) compiles without syntax/selector errors and yields the key selectors.
  def test_framework_compiles_to_css
    assert_includes @css, '.container'
    assert_includes @css, '.columns'
    refute_empty @css
  end

  # (b) invariant: gutter padding stays inside the column width (no overflow).
  def test_columns_are_border_box
    block = css_block('.columns')

    assert_match(/box-sizing:\s*border-box/, block, 'columns must be border-box so the gutter does not overflow the row')
  end

  # (b) invariant: collapse targets the real markup path (descendant, not child).
  def test_collapse_selector_targets_the_real_markup
    refute_match(/\.row\.collapse\s*>\s*\.columns/, @css, 'child selector never matches the nested <th class="columns">')
    assert_match(/\.row\.collapse\s+\.columns/, @css, 'collapse must use a descendant selector')
  end

  # (b) invariant: .container width tracks config.container_width through the bridge.
  def test_container_width_tracks_ruby_config
    assert_match(/max-width:\s*600px/, css_block('.container'))

    ActiveMail.configuration.container_width = 480
    css = ScssCompiler.compile

    assert_match(/max-width:\s*480px/, css_block('.container', css))
    refute_match(/max-width:\s*600px/, css_block('.container', css))
  end

  # (b) invariant: dark-mode rules are present (dual strategy survives compilation).
  def test_dark_mode_rules_present
    assert_includes @css, 'prefers-color-scheme: dark'
    assert_includes @css, '[data-ogsc]'
  end

  # (c) end-to-end: transpile the sample in the default layout head, run it through
  # the Premailer adapter, and assert the framework CSS lands inline on the columns.
  def test_delivered_email_has_framework_css_inlined
    delivered = inline(rendered_email)
    doc = Nokogiri::HTML(delivered)
    # Every column (sample + layout head/footer) must carry the inlined framework rule.
    columns = doc.css('th.columns')

    refute_empty columns, 'no columns rendered — layout/helper did not produce inlinable markup'
    columns.each do |col|
      assert_includes col['style'].to_s, 'box-sizing: border-box', 'framework gutter rule was not inlined onto the column'
    end
  end

  # (c) end-to-end: the sample's two large=6 columns fit within container_width once inlined.
  def test_two_half_columns_fit_within_container_width
    doc = Nokogiri::HTML(inline(rendered_email))
    halves = doc.css('th.large-6.columns')

    assert_equal 2, halves.size
    total = halves.sum { |col| outer_width(col['style'].to_s) }
    assert_operator total, :<=, ActiveMail.configuration.container_width,
                    "columns (#{total}px) overflow container (#{ActiveMail.configuration.container_width}px)"
  end

  private

  # Renders the REAL default layout through ActionView with StylesHelper extended
  # (as a host's mailer would), stubbing the asset read so the helper emits the
  # compiled framework CSS. This exercises the layout→helper→CompiledStylesheet
  # seam — if either stops injecting the <style> block, the inline assertions fail.
  def rendered_email
    ActiveMail::CompiledStylesheet.stub(:read, @css) do
      Dir.mktmpdir do |dir|
        views = File.join(dir, 'views')
        FileUtils.mkdir_p(File.join(views, 'mailers'))
        FileUtils.cp_r(File.join(ENGINE_VIEWS, 'layouts'), views)
        File.write(File.join(views, 'mailers', 'sample.html.inky-erb'), SAMPLE)

        lookup = ActionView::LookupContext.new([views])
        view = ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
        view.extend(ActiveMail::StylesHelper)

        view.render(template: 'mailers/sample', layout: 'layouts/activemail/mailer')
      end
    end
  end

  def inline(html)
    ActiveMail::Inliner::Premailer.new.inline(html)
  end

  # The effective horizontal footprint: border-box folds padding into the width,
  # so the inline max-width already is the outer width. Otherwise add the actual
  # left/right padding — `padding:` shorthand contributes to both sides.
  def outer_width(style)
    width = style[/max-width:\s*(\d+)px/, 1].to_i
    return width if style.include?('border-box')

    width + horizontal_padding(style)
  end

  def horizontal_padding(style)
    left = style[/padding-left:\s*(\d+)px/, 1]&.to_i
    right = style[/padding-right:\s*(\d+)px/, 1]&.to_i
    shorthand = style[/(?<!-)padding:\s*(\d+)px/, 1].to_i
    (left || shorthand) + (right || shorthand)
  end

  def css_block(selector, css = @css)
    css[/#{Regexp.escape(selector)}\s*\{[^}]*\}/m].to_s
  end
end
