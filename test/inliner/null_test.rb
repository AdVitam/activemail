# frozen_string_literal: true

require 'test_helper'

class NullInlinerTest < ActiveMailTest
  def test_returns_input_unchanged
    html = '<style>p{color:red}</style><p>x</p>'

    assert_equal html, ActiveMail::Inliner::Null.new.inline(html)
  end

  def test_is_a_noop
    assert ActiveMail::Inliner::Null.new.noop?
    refute ActiveMail::Inliner::Premailer.new.noop?
  end
end
