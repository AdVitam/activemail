# frozen_string_literal: true

require 'json'

transpile_calls = 0
ActiveMail::Core.prepend(Module.new do
  define_method(:transpile) do |html|
    transpile_calls += 1
    super(html)
  end
end)

Rails.application.initialize!

def capture
  yield
rescue StandardError => e
  { 'error' => e.class.name, 'message' => e.message }
end

welcome = capture { NotifierMailer.welcome.message }
welcome_calls = transpile_calls
plain = capture { PlainMailer.hello.message }

result = { 'booted' => true, 'pipeline' => ActiveMail::AssetPipeline.current.class.name }
result['welcome'] = if welcome.is_a?(Hash)
                      welcome
                    else
                      {
                        'html' => welcome.html_part.body.decoded,
                        'text' => welcome.text_part.body.decoded,
                        'attachment' => welcome.attachments.first.body.decoded,
                        'transpile_calls' => welcome_calls
                      }
                    end
result['plain'] = plain.is_a?(Hash) ? plain : plain.body.decoded
result['missing_stylesheet'] = capture { BrokenMailer.hello.message }
result['annotation_extensions'] = Rails::SourceAnnotationExtractor::Annotation.extensions.map { |pattern, _| pattern.source }
puts "PROBE_JSON:#{JSON.generate(result)}"
