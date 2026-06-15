# frozen_string_literal: true

require 'test_helper'

class PremailerInlinerTest < ActiveMailTest
  def test_inlines_style_into_attribute
    output = ActiveMail::Inliner::Premailer.new.inline('<style>p{color:red}</style><p>x</p>')

    assert_match(/<p[^>]*style="[^"]*color:\s*red/i, output)
  end
end
