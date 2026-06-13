# ActiveMail

**Opinionated, plug & play responsive email for Rails.** ActiveMail turns simple,
semantic tags into the bulletproof table markup email clients require, and ships a
batteries-included layer on top — a themeable SCSS framework, dark mode, design
tokens, automatic CSS inlining, generators, and test-time quality guards — so a
responsive, accessible email renders **out of the box**, with every default
overridable.

> Not affiliated with Rails core. The name echoes the `Active*` family by
> convention only.

Write this:

```html
<container>
  <row>
    <columns large="6">Left</columns>
    <columns large="6">Right</columns>
  </row>
</container>
```

and ActiveMail produces a fluid-hybrid, Outlook-safe table layout with MSO ghost
tables, `role="presentation"` on every table, and inline styles — markup that
renders consistently from Apple Mail to Outlook (Word engine) to Gmail mobile.

## Features

- **Semantic markup** → bulletproof tables (`<container>`, `<row>`, `<columns>`,
  `<button>`, `<menu>`, `<callout>`, `<spacer>`, …), with an extensible
  open/closed component registry.
- **Design tokens** as the single Ruby source of truth, bridged to SCSS.
- **Themeable SCSS framework** with built-in **dark mode** (`prefers-color-scheme`
  + Outlook `[data-ogsc]`).
- **Automatic CSS inlining** via a pluggable adapter (premailer by default, roadie
  optional, or your own).
- **Generators** to install, eject views/styles, and scaffold components.
- **Opt-in quality layer**: a Guard (size, `role`, `alt`, `lang`), preview
  renderer, Minitest assertions + RSpec matcher, and a `render_all` rake task.

## Installation

```ruby
# Gemfile
gem 'activemail'
```

```bash
bundle install
bin/rails g active_mail:install
```

The generator drops a commented initializer, a mailer layout, and wires the
framework stylesheet. It works zero-config; customize only what you want.

Name a mailer view `welcome.html.inky` (or compose with another engine:
`welcome.html.inky-erb`, `.inky-slim`, `.inky-haml`) and it is transpiled on
render. CSS is inlined automatically before delivery.

## Configuration

```ruby
# config/initializers/active_mail.rb
ActiveMail.configure do |config|
  config.template_engine  = :erb   # underlying engine for `.html.inky` (default :erb)
  config.column_count     = 12     # grid columns (default 12)
  config.container_width  = 600    # px width of <container> + MSO ghost table (default 600)
  config.on_parse_error   = :warn  # :ignore, :warn or :raise (default :warn)

  # CSS inliner: :premailer (default), :roadie, :null, or a custom
  # ActiveMail::Inliner::Base subclass/instance.
  config.inliner = :premailer
  # Set false if another inliner (e.g. premailer-rails) already runs on mailers;
  # `config.inliner = :null` also fully short-circuits ActiveMail's interceptor.
  config.register_inline_interceptor = true

  # Design tokens (see below).
  config.tokens.color :primary, '#2a9d8f'

  # Custom components (see "Custom components").
  config.register_component 'cta', Components::Cta
end
```

`on_parse_error` surfaces HTML the parser had to repair (unclosed/mismatched
tags, broken attributes) instead of silently sending a different email than
intended. `:warn` logs via `Rails.logger` when available (else `$stderr`); use
`:raise` in CI/staging to fail the build on malformed templates. Registered
component tags never trigger it. The parser knows HTML4 — HTML5-only tags
(`<section>`, …) are reported as unknown; register them as components or use
`:ignore`.

## Design tokens

Tokens are the single source of truth. Declare them **once in Ruby**; ActiveMail
bridges them to SCSS automatically (`$am-color-primary`, `$am-font-body`,
`$am-spacing-md`, …) so a component's inline color always matches the stylesheet.

```ruby
config.tokens.color   :primary,   '#2a9d8f'
config.tokens.color   :secondary, '#264653'
config.tokens.font    :heading,   'Georgia, serif'
config.tokens.spacing :lg,        '32px'

ActiveMail.tokens.color(:primary) # => "#2a9d8f"
```

Defaults are neutral (a calm teal `primary`, near-black `text`, white
`background`, …) and fully overridable. Under Sprockets the SCSS bridge is a
preprocessed partial; under Propshaft run `rake active_mail:tokens:export` to
materialize a static `_active_mail_tokens.scss`.

## Styling

The framework stylesheet lives at `active_mail/active_mail` and is themed entirely
by tokens — no hard-coded brand colors. It includes a fluid-hybrid grid, component
hooks (`.button`, `.cta`, `.callout`, `.spacer`, …), utilities, and dark mode.

Override at three levels, cheapest first:

1. **Tokens** (Ruby) — covers most theming.
2. **`bin/rails g active_mail:styles`** — eject the SCSS partials into your app to
   edit them; your copies shadow the gem's.
3. **`bin/rails g active_mail:views`** — eject the default layout + partials
   (`app/views/layouts/active_mail/*`); a same-named file in your app wins by
   Rails path precedence. Put your logo/header/footer here — those are the app's
   identity, not the gem's.

Dark mode ships on: a `<style>` block keys off `prefers-color-scheme: dark` (Apple
Mail/iOS) and Outlook's `[data-ogsc]`, with surfaces derived from your tokens.

## CSS inlining

Email clients (Gmail mobile, Orange.fr) strip `<style>`, so critical CSS must be
inlined. ActiveMail registers an ActionMailer interceptor that runs the configured
inliner on every outgoing HTML part — your `<style>` enhancement block (media
queries, dark mode) is preserved.

```ruby
config.inliner = :premailer   # default, hard dependency
config.inliner = :roadie      # add `gem 'roadie'` yourself
config.inliner = :null        # opt out (e.g. you run premailer-rails)
config.inliner = MyInliner.new # any ActiveMail::Inliner::Base
```

## Components

Every built-in tag and its rendered output. Tables omit
`border/cellpadding/cellspacing/role` below for brevity — they are always present.

### `<container>`

Fluid-hybrid wrapper, capped at `container_width`, wrapped in an MSO ghost table.

```html
<container>...</container>
```

```html
<!--[if mso | IE]><table role="presentation" align="center" width="600">...<![endif]-->
<table class="container" align="center" style="width:100%;max-width:600px;margin:0 auto;">
  <tbody><tr><td>...</td></tr></tbody>
</table>
<!--[if mso | IE]></td></tr></table><![endif]-->
```

### `<row>` / `<columns>`

Columns use `display:inline-block` + pixel `max-width` (natural stacking on
mobile) with MSO ghost cells restoring the grid in Outlook. `small`/`large`
attributes and `first`/`last`/`small-*`/`large-*` classes are preserved for
media-query enhancement.

```html
<row><columns large="6">Hi</columns></row>
```

Column widths are computed as `container_width × large / column_count`, capped
at `container_width`, **with no gutter model**: two `large="6"` columns sit
edge-to-edge (300px + 300px in a 600px container). Add padding inside your
columns for gutters, and keep the `large` sizes of a row summing to at most
`column_count`, otherwise the ghost cells will wrap in Outlook.

### `<button>`

Bulletproof button: the padding lives on the `<a>` so the whole control is
clickable. Variant classes (`primary`, `expand`, …) are preserved.

```html
<button href="#">Go</button>
```

`<button class="expand">` adds a centered link and an `.expander` cell.

### `<menu>` / `<item>`

```html
<menu><item href="#">Home</item></menu>
```

### `<callout>`

```html
<callout class="primary">Note</callout>
```

### `<spacer>`

`mso-line-height-rule:exactly` keeps Outlook from inflating the gap. Supports
`size`, `size-sm`, `size-lg` (responsive via `.hide-for-large`/`.show-for-large`).

```html
<spacer size="16"></spacer>
```

### `<block-grid>`

```html
<block-grid up="4"></block-grid>
```

### `<wrapper>`, `<h-line>`, `<center>`

- `<wrapper class="header">` → `<table class="header wrapper" align="center" style="width:100%;">` with a `.wrapper-inner` cell.
- `<h-line>` → a full-width single-cell table for a horizontal rule.
- `<center>` adds `align="center"` and `.float-center` to its element children (and `.float-center` to nested menu items).

### `<inky>`

Renders a bare `<tr>`, useful inside hand-written tables.

### `<raw>`

Anything between `<raw>` and `</raw>` is passed through untouched (multi-line
supported). Raw blocks cannot be nested.

```html
<raw><% liquid_or_mso_conditional %></raw>
```

### Token-driven built-ins: `<cta>` and `<info-box>`

Brand-neutral, token-styled components shipped with the gem but **not registered
by default** (so they never collide with your tags). Register them to use:

```ruby
config.register_component 'cta', ActiveMail::Components::Cta
config.register_component 'info-box', ActiveMail::Components::InfoBox
```

```html
<cta href="https://example.com">Go</cta>
<cta href="#" class="secondary">Also go</cta>
```

`<cta>` renders a bulletproof button using `tokens.color(:primary)` (or
`:secondary` with `class="secondary"`); it raises if `href` is missing.

## Custom components

Register your own tag with a class that inherits from
`ActiveMail::Components::Base` and implements `#transform(node, inner)`. You get
the matched Nokogiri node (full DOM access) and the already-transformed inner
HTML; return the replacement markup string. The generator scaffolds one:

```bash
bin/rails g active_mail:component Divider
```

```ruby
class Divider < ActiveMail::Components::Base
  def transform(node, _inner)
    klass = combine_classes(node, 'divider')
    %(<table class="#{klass}" role="presentation" style="width:100%;"><tbody><tr><td></td></tr></tbody></table>)
  end
end

ActiveMail.configuration.register_component('divider', Divider)
```

Helpers available from `Base`: `combine_classes`, `combine_attributes`,
`pass_through_attributes`, `class?`, `target_attribute`, `escape_attr`,
`style_attribute`, `column_count`, `container_width`.

Per-instance overrides (including replacing a built-in tag) are also possible:

```ruby
ActiveMail::Core.new(components: { 'button' => MyButton }).release_the_kraken(source)
```

## Generators

| Generator | Purpose |
|---|---|
| `active_mail:install` | Initializer + mailer layout + stylesheet wiring (works zero-config). `--haml` / `--slim` supported. |
| `active_mail:views` | Eject the default layout + partials for customization. |
| `active_mail:styles` | Eject the SCSS framework partials for customization. |
| `active_mail:component NAME` | Scaffold a component class + print its register snippet. |

## Testing & quality

An **opt-in** layer (never loaded by `require 'active_mail'`). Require it from your
test suite.

```ruby
# Minitest — require the assertions module explicitly:
require 'active_mail/quality/minitest'

class MailerTest < ActiveSupport::TestCase
  include ActiveMail::Quality::Minitest

  test 'welcome email is sound' do
    assert_email_quality(rendered_html)
  end
end
```

```ruby
# RSpec — require the matcher (registers be_a_valid_email when RSpec is loaded):
require 'active_mail/quality/rspec'

expect(rendered_html).to be_a_valid_email
```

The Guard checks byte size (Gmail clips ~102 KB), `role="presentation"` on every
table, `alt` on every image, and `lang` on full documents — all thresholds
configurable:

```ruby
ActiveMail::Quality.configure do |c|
  c.required_previews = %w[welcome_mailer#welcome]
  c.guard = ActiveMail::Quality::Guard.new(max_bytes: 90_000)
end
```

`rake active_mail:emails:render_all` renders every ActionMailer preview to disk
for visual diffing and fails on any guard violation among `required_previews`.

## Email-client compatibility policy

Targets the real-world client landscape as of 2026:

- **Outlook for Windows (Word engine)** — MSO ghost tables/cells and `mso-*`
  properties keep layouts intact.
- **Orange.fr (major FR webmail)** — degraded but functional: the markup never
  *depends* on `!important`, `border-radius`, `background-image`, flex, or grid.
- **Gmail mobile** — strips most `<style>`; critical layout is inlined, with
  enhancement CSS left in a `<style>` block.
- **Accessibility** — `role="presentation"` on every layout table; provide `alt`
  text and sufficient contrast.

## Programmatic use

```ruby
ActiveMail::Core.new.release_the_kraken('<container><row><columns>Hi</columns></row></container>')
ActiveMail::Core.new(column_count: 24, container_width: 480).release_the_kraken(source)
```

## Development

```bash
bundle install
bundle exec rake test     # minitest
bundle exec rubocop
bundle exec srb tc        # Sorbet
```

## License

MIT. See [`LICENSE.txt`](LICENSE.txt).
