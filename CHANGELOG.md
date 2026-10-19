# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-10-19

Behaviour changes to review before upgrading: see [UPGRADING.md](UPGRADING.md).

### Added

- `container_gutter` spacing token (16px) and `$am-container-gutter`: the first
  and last column of a row carry it as an outer, border-box, inlined padding;
  nested columns do not repeat it.
- `<title>` in the layout head, set to the message subject (new
  `layouts/activemail/_document_head` partial).
- Quality rules, on by default and disableable: `title`, `anchor_href`,
  `placeholder` (`BuiltinRules::PLACEHOLDER`), `unsupported_color`,
  `text_entities`.
- `Quality::Configuration#allow_declined` and the `allow_declined:` option of
  `Guard#violations`, `Guard#valid?`, `assert_email_quality` and
  `be_a_valid_email`.
- `Quality::Configuration#rule_exemptions` (by preview name or `preview#email`) and
  the `skip:` option of `Guard#violations`, `Guard#valid?`, `assert_email_quality`
  and `be_a_valid_email`: exempt a preview from named rules, built-in or custom,
  without disabling them for every preview.
- `mso-padding-alt` on the button cell so Outlook keeps the padding.

### Changed

- A nested `<columns>` ghost cell and `max-width` are computed against the
  content box of the enclosing columns (their share minus their padding)
  instead of the container.
- The MSO ghost cell of a column wraps it in its own `<table><tr>` (the `<th>`
  used to sit directly in a `<td>`).
- Conditional comments use `<!--[if mso]>` instead of `<!--[if mso | IE]>`.
- `<button>` and `<cta>`: the fill and the radius live on the cell only; the
  `<a>` carries `display:inline-block`, the body font and a `1.25` line height.
  The dark-mode fill targets the cell.
- `<center>` renders a `<center align="center" class="float-center">` and no
  longer rewrites its children.
- A mailer that declines to send (`NullMail`) is a `declined` violation unless
  allowed.
- The generated layouts render the same `_document_head`, `_head` and `_footer`
  partials as the gem layout.
- With Premailer the parsed framework CSS is cached per stylesheet fingerprint
  (a FIFO of 16) instead of being re-parsed for every email.

### Removed

- The `.columns.first.last` SCSS rule: a lone column now takes both container
  gutters through `.first` and `.last`.

## [2.0.0] - 2026-10-16

Breaking release: see [UPGRADING.md](UPGRADING.md).

### Fixed

- Emails rendered by a real Rails app shipped without the framework CSS: the
  stylesheet lookup probed `config.assets` (an `OrderedOptions` that answers
  every `respond_to?` with `nil`) and the `<link>` fallback was stripped by
  Premailer. Assets are now read from the actual Sprockets environment/manifest
  or Propshaft load path.
- Propshaft hosts no longer risk a boot crash on `assets.precompile`.
- `<raw>` content is no longer transformed when the layout re-rendered the view,
  and an author's literal `###RAW0###` is left intact.
- The word "doctype" in content and `&nbsp;`-like characters inside `<style>`
  are no longer rewritten.
- Numeric attributes are parsed in strict base 10 (`"010"` was read as 8).
- `<cta>`, `<info-box>`, `<spacer>` and `<block-grid>` keep `id`, `aria-*`,
  `data-*` and the author's `style`.
- Column widths only count sibling columns (a sibling `<p>` skewed them).
- The secondary button and info-box tokens now reach the stylesheet and dark
  mode (1.1.0 announced it, but the SCSS ignored them).
- `.h-line`, `.block-grid.up-N`, `.menu`, `.expander` had no CSS.
- `render_all` refuses an `output_dir` outside the app and only deletes its own
  files (it used to `rm_rf` the whole directory).
- The responsive breakpoint follows `container_width` instead of a fixed 596px.
- Code annotations are registered for the real `inky-*` extensions.

### Changed

- One transpilation and one inlining pass per email, hooked on
  `ActionMailer::Base#render_to_body`; text parts, attachments and
  non-ActiveMail emails are untouched.
- `activemail_inline_styles(*paths)` embeds host stylesheets too and raises
  `ActiveMail::StylesheetNotFound` instead of warning.
- `<button>` and `<cta>` share one bulletproof, token-styled, inlined rendering.
- SCSS uses the module system (`@use`/`@forward`, `sass:color`, `sass:math`).
- Transpilation is linear in the document size (200 nested rows: ×3.7,
  2,000 raw blocks: ×35) and reuses a memoized `Core`.
- `Quality::Guard` is extensible with `Quality::Rule` and gains
  `translation_missing`, `single_root`, `text_part_present`, `text_part_plain`.
- `Quality` gains `locales`, `formats`, `around_each` and `output_filters`.
- Errors share the `ActiveMail::Error` base class.

### Removed

- `ActiveMail::Inliner::Interceptor` and `config.register_inline_interceptor`.
- `ActiveMail::CompiledStylesheet` (replaced by `ActiveMail::AssetPipeline`).
- The `<inky>` tag.
- `IGNORED_ON_PASSTHROUGH`, `combine_attributes`, `pass_through_attributes`,
  `bulletproof_button_table` and `BUTTON_PADDING`.
- `stylesheet_link_tag` from the layouts.
- The manual `workflow_dispatch` release trigger.

## [1.2.3] - 2026-10-09

### Changed

- Bound the runtime dependencies: `nokogiri` `< 1.20`, `premailer` `< 2`, `sorbet-runtime` `>= 0.5.10600, < 0.7`
  (`0.5.10600` is the first build supporting Ruby 3.2). The `nokogiri` cap guards the parse-error
  reporter, which relies on libxml2 error internals that libxml2 2.14 (nokogiri 1.20) may change (#18).
- Test suite supports minitest 6 (`minitest-mock` is now an explicit test dependency).
- CI checks the lowest supported dependency versions (`gemfiles/minimum.gemfile`); Dependabot enabled.

## [1.2.2] - 2026-07-23

### Changed

- Publish to RubyGems via trusted publishing (OIDC) instead of a long-lived API key.
- Harden the `blank_link_rel=` setter (internal, no behaviour change).

## [1.2.1] - 2026-07-01

### Changed

- Renamed the internal `ActiveMail::Core#release_the_kraken` to `#transpile`.
- Neutralised test fixtures (example URLs) and severed the upstream fork link.

## [1.2.0] - 2026-07-01

### Added

- `config.blank_link_rel` (default `"noopener"`): a `rel` is now emitted automatically on
  `target="_blank"` anchors. Set `nil` to disable; an explicit `rel="…"` still wins.

## [1.1.1] - 2026-06-16

### Added

- `cta` and `info-box` are now registered out of the box in `DEFAULT_COMPONENTS`,
  alongside `button`/`callout`. The components and their styles already shipped but
  the tags required manual registration; `<cta>`/`<info-box>` now work by default.

## [1.1.0] - 2026-06-15

### Added

- `radius` token group (`button`/`box`) and `Tokens#radius`/`#radius!` accessors.
- `Tokens#button_style(variant)` resolver and the `Tokens::ButtonStyle` value
  object: button variants (incl. an **outline** secondary) are now token-driven —
  set `<variant>_text`/`<variant>_border` colors instead of forking the component.
- Box-scoped `info_box_background`/`info_box_border`/`info_box_text` tokens
  (falling back to the page palette) plus a box `border-radius`.
- `Tokens#load(group: {...})` bulk-loader and a single `Tokens#to_h` snapshot.

### Changed

- `<button>` and `<cta>` share a `bulletproof_button_table` scaffold; `<cta>`
  drops its hardcoded `4px` radius in favor of the `radius` token.
- The corner radius is now applied by default on `.button`/`.cta` (the opt-in
  `.radius` class is gone).

### Removed

- `Tokens#colors`/`#fonts`/`#spacings` readers — use `Tokens#to_h` instead.

## [1.0.2] - 2026-06-15

### Fixed

- Moved the framework styles helper to `app/helpers/active_mail/` so the host
  application's Zeitwerk loader resolves it to `ActiveMail::StylesHelper`. Under
  the previous `app/helpers/activemail/` path the default inflector expected
  `Activemail::StylesHelper`, making the engine's `helper ActiveMail::StylesHelper`
  raise `NameError` at boot in any mounting app.

## [1.0.1] - 2026-06-15

### Changed

- Simplified the gem description and README; removed legacy branding.
- Unified the namespace to `ActiveMail` (gem name = require path = entry file =
  namespace). Plain `require 'activemail'` now loads everything, so the
  `require: 'active_mail'` workaround is no longer needed.

## [1.0.0] - 2026-06-13

First release of **ActiveMail**, an opinionated, plug & play responsive email
toolkit for Rails.

### Added

- **Semantic markup engine.** Simple tags (`<container>`, `<row>`, `<columns>`,
  `<button>`, `<menu>`, `<callout>`, `<spacer>`, `<wrapper>`...) transpile to
  bulletproof, email-client-ready table markup.
- **Extensible component registry (open/closed).** Each component is a class
  (`ActiveMail::Components::*`) inheriting from `ActiveMail::Components::Base`.
  Register your own tags with
  `ActiveMail.configuration.register_component('my-tag', MyComponent)`; custom
  components receive the matched Nokogiri node and full DOM access.
- **`role="presentation"` on every generated layout table** for accessibility.
- **MSO ghost tables/cells** around `<container>`, `<row>`/`<columns>`, so the
  fluid-hybrid layout still renders as a grid in Outlook (Word engine).
- **`container_width` configuration** (default `600`), global or per
  `ActiveMail::Core.new(container_width:)`.
- **Bulletproof `<button>`**: padding carried by the `<a>` so the whole button is
  clickable.
- **`mso-line-height-rule:exactly`** on `<spacer>` to stop Outlook inflating it.
- **Multi-line `<raw>` support.**
- **`on_parse_error`** (`:ignore`/`:warn`/`:raise`) surfaces HTML the parser had
  to repair instead of silently shipping a different email.
- **Sorbet `# typed: strict`** across `lib/`, with full signatures.
- **Minitest suite** with golden-markup assertions for every component, error and
  edge cases, and the Rails template-handler integration path.
- **GitHub Actions CI**: Ruby 3.2/3.3/3.4/4.0 × Rails 7.1/8.0/8.1.

### Markup notes

- **Fluid-hybrid layout.** `<columns>` use `display:inline-block` with a pixel
  `max-width` so columns stack naturally on small screens without a media query,
  and are restored to a grid in Outlook via ghost cells. The `small-*`, `large-*`,
  `first`, `last` classes are preserved for media-query enhancement. Ghost-cell
  widths are `container_width × large / column_count`, capped at `container_width`,
  with **no gutter model** — add padding inside columns for gutters.
- All generated tables carry explicit `border="0" cellpadding="0" cellspacing="0"`
  and inline `style` (no reliance on `!important` or `border-radius`, both stripped
  by Orange.fr webmail).
- The engine emits no hard-coded colors, so app-side dark mode
  (`prefers-color-scheme`, `[data-ogsc]`) works unhindered.

### Compatibility

- Ruby `>= 3.2` (tested up to 4.0).
- Rails `>= 7.1` (tested up to 8.1).
- Nokogiri `>= 1.16`.

[2.1.0]: https://github.com/AdVitam/activemail/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/AdVitam/activemail/compare/v1.2.3...v2.0.0
[1.0.1]: https://github.com/AdVitam/activemail/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AdVitam/activemail/releases/tag/v1.0.0
