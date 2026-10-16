# frozen_string_literal: true

require 'test_helper'

class ContainerTest < ActiveMailTest
  def test_wraps_in_fluid_hybrid_table_with_mso_ghost_table
    assert_renders(
      '<container></container>',
      <<~HTML
        <!--[if mso | IE]><table role="presentation" border="0" cellpadding="0" cellspacing="0" align="center" width="600"><tr><td><![endif]-->
        <table class="container" style="width:100%;max-width:600px;margin:0 auto;" role="presentation" border="0" cellpadding="0" cellspacing="0" align="center"><tbody><tr><td></td></tr></tbody></table>
        <!--[if mso | IE]></td></tr></table><![endif]-->
      HTML
    )
  end

  def test_passes_through_attributes
    table = Nokogiri::HTML.fragment(render('<container id="main" aria-label="Mail"></container>')).at_css('table.container')

    assert_equal 'main', table['id']
    assert_equal 'Mail', table['aria-label']
  end

  def test_keeps_passed_classes
    output = render('<container class="body"></container>')

    assert_includes output, 'class="body container"'
  end

  def test_honours_configured_container_width
    ActiveMail.configuration.container_width = 700
    output = render('<container></container>')

    assert_includes output, 'max-width:700px'
    assert_includes output, 'width="700"'
  end

  def test_constructor_option_overrides_container_width
    output = render('<container></container>', container_width: 480)

    assert_includes output, 'max-width:480px'
  end

  def test_works_inside_a_full_document
    output = render(<<~INKY)
      <!doctype html><html><body><container></container></body></html>
    INKY

    assert_includes output, '<!DOCTYPE html>'
    assert_includes output, 'class="container"'
  end
end
