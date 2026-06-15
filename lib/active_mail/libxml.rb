# typed: strict
# frozen_string_literal: true

module ActiveMail
  # libxml2 XML_HTML_UNKNOWN_TAG: emitted for every non-HTML4 tag (HTML5/custom
  # tags), not actual malformedness. Shared by the engine and the quality layer.
  LIBXML_UNKNOWN_TAG_CODE = 801
end
