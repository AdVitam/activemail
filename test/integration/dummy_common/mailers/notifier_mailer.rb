# frozen_string_literal: true

class NotifierMailer < ActionMailer::Base
  layout 'mailer'

  def welcome
    attachments['note.html'] = { mime_type: 'text/html', content: '<style>.a{color:red}</style><p class="a">x</p>' }
    mail(to: 'to@example.com', from: 'from@example.com', subject: 'Welcome')
  end
end
