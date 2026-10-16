# ActiveMail

**Opinionated, plug & play responsive email for Rails.** ActiveMail turns simple,
semantic tags into the bulletproof table markup email clients require, and ships a
batteries-included layer on top — a themeable SCSS framework, dark mode, design
tokens, automatic CSS inlining, generators, and test-time quality guards — so a
responsive, accessible email renders **out of the box**, with every default
overridable.

Not affiliated with Rails core.

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
gem 'activemail', '~> 2.0'
```

```bash
bundle install
bin/rails g activemail:install
```

The generator drops a commented initializer, a mailer layout, and wires the
framework stylesheet. It works zero-config; customize only what you want.

Name a mailer view `welcome.html.inky` (or compose with another engine:
`welcome.html.inky-erb`, `.inky-slim`, `.inky-haml`) and it is transpiled on
render. Each email is transpiled and its CSS inlined exactly once, when the
mailer renders it (view and layout together).

## Configuration

```ruby
# config/initializers/activemail.rb
ActiveMail.configure do |config|
  config.template_engine  = :erb   # underlying engine for `.html.inky` (default :erb)
  config.column_count     = 12     # grid columns (default 12)
  config.container_width  = 600    # px width of <container> + MSO ghost table (default 600)
  config.on_parse_error   = :warn  # :ignore, :warn or :raise (default :warn)

  # CSS inliner: :premailer (default), :roadie, :null, or a custom
  # ActiveMail::Inliner::Base subclass/instance.
  config.inliner = :premailer

  # Design tokens (see below).
  config.tokens.color :primary, '#2a9d8f'

  # Custom components (see "Custom components").
  config.register_component 'divider', Divider
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
`background`, …) and fully overridable. Optional tokens fall back to a base
token: `primary_text`/`secondary_text` → `button_text`, `primary_border`/
`secondary_border` → none, `info_box_background`/`_border`/`_text` →
`background`/`border`/`text`. Ruby components and the stylesheet read the same
resolved values. Under Sprockets the SCSS bridge is a
preprocessed partial; under Propshaft run `rake activemail:tokens:export` to
materialize a static `_activemail_tokens.scss`.

## Styling

The framework stylesheet lives at `activemail/activemail` and is themed entirely
by tokens — no hard-coded brand colors. It includes a fluid-hybrid grid, component
hooks (`.button`, `.cta`, `.callout`, `.spacer`, …), utilities, and dark mode.

Override at three levels, cheapest first:

1. **Tokens** (Ruby) — covers most theming. Any framework variable can also be
   configured from your own stylesheet with the Sass module system:

   ```scss
   // app/assets/stylesheets/emails/emails.scss
   @use "activemail/activemail" with (
     $am-button-secondary-color: #264653,
     $am-breakpoint: 640px
   );
   ```

2. **`bin/rails g activemail:styles`** — eject the SCSS partials into your app to
   edit them; your copies shadow the gem's.
3. **`bin/rails g activemail:views`** — eject the default layout + partials
   (`app/views/layouts/activemail/*`); a same-named file in your app wins by
   Rails path precedence. Put your logo/header/footer here — those are the app's
   identity, not the gem's.

Dark mode ships on: a `<style>` block keys off `prefers-color-scheme: dark` (Apple
Mail/iOS) and Outlook's `[data-ogsc]`, with surfaces derived from your tokens.

## CSS inlining

Email clients (Gmail mobile, Orange.fr) strip `<style>`, so critical CSS must be
inlined. When a mailer renders an inky HTML template, ActiveMail transpiles the
whole body (view + layout) and runs the configured inliner once. Text parts,
attachments and non-ActiveMail emails are never touched; your `<style>`
enhancement block (media queries, dark mode) is preserved.

The layout embeds the compiled stylesheets with `activemail_inline_styles`
(Sprockets or Propshaft); pass your own on top of the framework's:

```erb
<%= activemail_inline_styles %>                  <%# framework only %>
<%= activemail_inline_styles "emails/emails" %>  <%# your stylesheet @use-ing the framework %>
```

A missing or empty asset raises `ActiveMail::StylesheetNotFound`: an email is
never sent unstyled. An inliner failure raises `ActiveMail::Inliner::Error`
(the adapter's exception is kept as `#cause`).

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

Bulletproof button styled inline from the tokens (`Tokens#button_style`): the
padding lives on the `<a>` so the whole control is clickable, and a variant
border sits on the cell only. `class="secondary"` selects the secondary variant;
`expand` makes it full width; without `href` the label renders as a `<span>`.

```html
<button href="#" class="secondary">Go</button>
```

```html
<table class="secondary button"><tbody><tr><td>
  <table><tbody><tr>
    <td style="background:#264653;border-radius:4px;">
      <a href="#" style="display:inline-block;text-decoration:none;padding:12px 24px;background:#264653;color:#ffffff;font-weight:bold;border-radius:4px;">Go</a>
    </td>
  </tr></tbody></table>
</td></tr></tbody></table>
```

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
- `<h-line>` → a full-width single-cell table drawn as a 1px rule in the `border` color.
- `<center>` adds `align="center"` and `.float-center` to its element children (and `.float-center` to nested menu items).

### `<raw>`

Anything between `<raw>` and `</raw>` is passed through untouched (multi-line
supported), including through the layout. Raw blocks cannot be nested.

```html
<raw><% liquid_or_mso_conditional %></raw>
```

### Token-driven built-ins: `<cta>` and `<info-box>`

Brand-neutral, token-styled components, registered by default.

```html
<cta href="https://example.com">Go</cta>
<cta href="#" class="secondary">Also go</cta>
```

`<cta>` renders exactly like `<button>` with a `cta` class; it raises if `href`
is missing. `<info-box>` is a callout styled from the `info_box_*` tokens.

Every component keeps the author's `class` and `style` (merged, never
duplicated) and passes `id`, `aria-*`, `data-*` and other attributes through to
its root element.

## Custom components

Register your own tag with a class that inherits from
`ActiveMail::Components::Base` and implements `#transform(node, inner)`. You get
the matched Nokogiri node (read its attributes) and `inner`, an opaque slot
standing for the already-transformed children: interpolate it exactly once where
the children belong, never parse or alter it (a component that drops it drops
its children). Return the replacement markup string. The generator scaffolds one:

```bash
bin/rails g activemail:component Divider
```

The generator namespaces the class as `Components::Divider` (under
`app/mailers/components/`); registering by tag, the namespace is yours to choose.
A minimal hand-written equivalent:

```ruby
class Divider < ActiveMail::Components::Base
  def transform(node, inner)
    %(<table#{root_attributes(node, classes: 'divider', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr><td>#{inner}</td></tr></tbody></table>)
  end

  private

  def consumed_attributes
    TABLE_RESET_ATTRIBUTES
  end
end

ActiveMail.configuration.register_component('divider', Divider)
```

`root_attributes` emits the merged `class`, the merged `style` and every
pass-through attribute; override `consumed_attributes` to list the attributes
your component reads itself (they are not passed through). Other helpers:
`class?`, `escape_attr`, `column_count`, `container_width`.

Per-instance overrides (including replacing a built-in tag) are also possible:

```ruby
ActiveMail::Core.new(components: { 'button' => MyButton }).transpile(source)
```

## Generators

| Generator | Purpose |
|---|---|
| `activemail:install` | Initializer + mailer layout + stylesheet wiring (works zero-config). `--haml` / `--slim` supported. |
| `activemail:views` | Eject the default layout + partials for customization. |
| `activemail:styles` | Eject the SCSS framework partials for customization. |
| `activemail:component NAME` | Scaffold a component class + print its register snippet. |

## Testing & quality

An **opt-in** layer (never loaded by `require 'activemail'`). Require it from your
test suite.

```ruby
# Minitest — require the assertions module explicitly:
require 'activemail/quality/minitest'

class MailerTest < ActiveSupport::TestCase
  include ActiveMail::Quality::Minitest

  test 'welcome email is sound' do
    assert_email_quality(WelcomeMailer.welcome(user)) # a message, or an HTML string
  end
end

class EmailPreviewsTest < ActiveSupport::TestCase
  include ActiveMail::Quality::Minitest

  assert_quality_for_all_previews # one test per preview email and locale
end
```

```ruby
# RSpec — require the matcher (registers be_a_valid_email when RSpec is loaded):
require 'activemail/quality/rspec'

expect(rendered_html).to be_a_valid_email
```

The Guard checks byte size (Gmail clips ~102 KB), parse errors,
`role="presentation"` on every table, `alt` on every image, `lang` on full
documents, a single `<html>`/`<body>`, missing translations, and — given a
message — a plain text part. Built-in rules can be disabled and your own added:

```ruby
signature = ActiveMail::Quality::Rule.html(:single_signature) do |doc, _html|
  'signature rendered twice' if doc.css('.signature').size > 1
end

ActiveMail::Quality.configure do |c|
  c.required_previews = %w[welcome_mailer#welcome]
  c.guard = ActiveMail::Quality::Guard.new(max_bytes: 90_000, disable: %i[img_alt], rules: [signature])
  c.locales = %i[fr en]                      # or ->(preview) { [...] }
  c.formats = %i[html text]
  c.around_each = lambda do |_preview, _email, _locale, &render|
    ActiveRecord::Base.transaction { render.call; raise ActiveRecord::Rollback } # previews leave no data behind
  end
  c.output_filters = [[/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, '<uuid>']] # applied to written files only
  c.output_dir = 'tmp/email_previews'        # relative, inside Rails.root
end
```

`Rule.html` blocks receive the parsed document and the raw HTML; `Rule.message`
blocks receive the `Mail::Message`. Return `nil`, a message or an array of
messages.

`rake activemail:emails:render_all` renders every ActionMailer preview (each
locale and format) to `output_dir` for visual diffing and fails on any guard
violation among `required_previews`. It only replaces its own `.html`/`.txt`
files.

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
ActiveMail.configuration.core.transpile('<container><row><columns>Hi</columns></row></container>')
ActiveMail::Pipeline.call(source) # transpile + inline
ActiveMail::Core.new(column_count: 24, container_width: 480).transpile(source)
```

## Development

```bash
bundle install
bundle exec rake test     # minitest
bundle exec rubocop
bundle exec srb tc        # Sorbet
```

## License

MIT. See [`LICENSE.txt`](LICENSE.txt), which retains the original ZURB copyright.
