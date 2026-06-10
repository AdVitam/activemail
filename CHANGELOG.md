# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-06-11

A full modernization. v2 is a generalist gem usable by any Rails project, with
markup updated to 2026 email best practices.

### Added

- **Extensible component registry (open/closed).** Each component is now a class
  (`Inky::Components::*`) inheriting from `Inky::Components::Base`. Register your
  own tags with `Inky.configuration.register_component('my-tag', MyComponent)`;
  custom components receive the matched Nokogiri node and full DOM access.
- **`role="presentation"` on every generated layout table** for accessibility.
- **MSO ghost tables/cells** around `<container>`, `<row>`/`<columns>`, so the
  fluid-hybrid layout still renders as a grid in Outlook (Word engine).
- **`container_width` configuration** (default `600`), settable globally or per
  `Inky::Core.new(container_width:)`.
- **Bulletproof `<button>`**: padding carried by the `<a>` so the whole button is
  clickable.
- **`mso-line-height-rule:exactly`** on `<spacer>` to stop Outlook inflating it.
- **Multi-line `<raw>` support** (upstream PR #101).
- **Sorbet `# typed: strict`** across `lib/`, with full signatures.
- **Minitest suite** with golden-file coverage for every component plus error and
  edge cases.
- **GitHub Actions CI**: Ruby 3.2/3.3/3.4/4.0 × Rails 7.1/8.0/8.1.

### Changed

- **Layout is now fluid-hybrid.** `<columns>` use `display:inline-block` with a
  pixel `max-width` so columns stack naturally on small screens without a media
  query, and are restored to a grid in Outlook via ghost cells. The `small-*`,
  `large-*`, `first`, `last` classes are preserved for media-query enhancement.
- All generated tables carry explicit `border="0" cellpadding="0" cellspacing="0"`
  and inline `style` (no reliance on `!important` or `border-radius`, both stripped
  by Orange.fr webmail).
- Component classes are keyed by tag string in the registry; the constructor
  `components:` option now maps tag strings to component classes.

### Removed

- **`foundation_emails` runtime dependency.** The gem no longer ships Foundation's
  SCSS; styling is the application's responsibility (inline critical CSS, plus a
  `<style>` block for media-query/dark-mode enhancement). To keep the previous
  behavior, add `foundation_emails` to your own Gemfile and import its SCSS.
- Legacy `gemfiles/` (Rails 3-6) and `.travis.yml`. CI is now GitHub Actions.

### Compatibility

- Ruby `>= 3.2` (tested up to 4.0).
- Rails `>= 7.1` (tested up to 8.1).
- Nokogiri `>= 1.16`.

### Migration from 1.x

- The generated markup changed. If you snapshot-test rendered emails, re-record
  the snapshots.
- If you relied on Foundation's SCSS classes for styling, add `foundation_emails`
  to your Gemfile yourself, or provide your own styles for the preserved class
  hooks (`.row`, `.columns`, `.button`, `.menu`, `.callout`, `.spacer`, ...).
- Custom components previously passed as `components: { tag: 'tag-name' }` string
  maps are replaced by the class-based registry. Use `register_component`.

[2.0.0]: https://github.com/foundation/inky-rb/releases/tag/v2.0.0
