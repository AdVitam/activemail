# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  `.radius` class is gone); `.button.secondary`/`.cta.secondary` mirror the
  secondary color/border tokens.

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

[1.0.1]: https://github.com/AdVitam/activemail/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AdVitam/activemail/releases/tag/v1.0.0
