# frozen_string_literal: true

class NotifierMailerPreview < ActionMailer::Preview
  def welcome
    NotifierMailer.welcome
  end
end
