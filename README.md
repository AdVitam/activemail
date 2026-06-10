# Inky

Inky is an HTML-based templating language that converts simple, semantic tags
into the verbose, bulletproof table markup that email clients require.

Write this:

```html
<container>
  <row>
    <columns large="6">Left</columns>
    <columns large="6">Right</columns>
  </row>
</container>
```

and Inky produces a fluid-hybrid, Outlook-safe table layout with MSO ghost
tables, `role="presentation"` on every table, and inline styles — markup that
renders consistently from Apple Mail to Outlook (Word engine) to Gmail mobile.

> **v2.0** is a ground-up modernization: extensible component registry, modern
> email markup (2026 best practices), Sorbet types, and Ruby 3.2-4.0 / Rails
> 7.1-8.1 support. See [`CHANGELOG.md`](CHANGELOG.md) and the
> [migration guide](#migrating-from-1x).

## Installation

```ruby
# Gemfile
gem 'inky-rb', require: 'inky'
```

```bash
bundle install
```

Inky registers ActionView template handlers automatically. Name a mailer view
`welcome.html.inky` (or compose with another engine: `welcome.html.inky-erb`,
`.inky-slim`, `.inky-haml`) and it is transpiled on render.

For programmatic use:

```ruby
Inky::Core.new.release_the_kraken('<container><row><columns>Hi</columns></row></container>')
```

## Configuration

```ruby
Inky.configure do |config|
  config.template_engine  = :erb   # underlying engine for `.html.inky` (default :erb)
  config.column_count     = 12     # grid columns (default 12)
  config.container_width  = 600    # px width of <container> and MSO ghost table (default 600)
end
```

Per-render overrides:

```ruby
Inky::Core.new(column_count: 24, container_width: 480).release_the_kraken(source)
```

## Components

Every built-in tag and its rendered output. Tables omit
`border/cellpadding/cellspacing/role` below for brevity — they are always
present in the real output.

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

```html
<table class="row" style="width:100%;"><tbody><tr>
  <!--[if mso | IE]><td width="300" valign="top"><![endif]-->
  <th class="small-12 large-6 columns first last" style="display:inline-block;vertical-align:top;width:100%;max-width:300px;">
    <table style="width:100%;"><tbody><tr><th style="font-weight:normal;text-align:left;">Hi</th></tr></tbody></table>
  </th>
  <!--[if mso | IE]></td><![endif]-->
</tr></tbody></table>
```

Column widths are computed as `container_width × large / column_count`, capped
at `container_width`, **with no gutter model**: two `large="6"` columns sit
edge-to-edge (300px + 300px in a 600px container). Add padding inside your
columns for gutters, and keep the `large` sizes of a row summing to at most
`column_count`, otherwise the ghost cells will wrap in Outlook.

### `<button>`

Bulletproof button: the padding lives on the `<a>` so the whole control is
clickable. Variant classes (`primary`, `expand`, ...) are preserved.

```html
<button href="#">Go</button>
```

```html
<table class="button"><tbody><tr><td>
  <table><tbody><tr><td>
    <a href="#" style="display:inline-block;text-decoration:none;padding:12px 24px;">Go</a>
  </td></tr></tbody></table>
</td></tr></tbody></table>
```

`<button class="expand">` adds a centered link and an `.expander` cell.

### `<menu>` / `<item>`

```html
<menu><item href="#">Home</item></menu>
```

```html
<table class="menu"><tbody><tr><td>
  <table><tbody><tr><th class="menu-item"><a href="#">Home</a></th></tr></tbody></table>
</td></tr></tbody></table>
```

### `<callout>`

```html
<callout class="primary">Note</callout>
```

```html
<table class="callout" style="width:100%;"><tbody><tr>
  <th class="primary callout-inner">Note</th>
  <th class="expander"></th>
</tr></tbody></table>
```

### `<spacer>`

`mso-line-height-rule:exactly` keeps Outlook from inflating the gap. Supports
`size`, `size-sm`, `size-lg` (responsive via `.hide-for-large`/`.show-for-large`).

```html
<spacer size="16"></spacer>
```

```html
<table class="spacer" style="width:100%;"><tbody><tr>
  <td height="16" style="font-size:16px;line-height:16px;mso-line-height-rule:exactly;">&nbsp;</td>
</tr></tbody></table>
```

### `<block-grid>`

```html
<block-grid up="4"></block-grid>
```

```html
<table class="block-grid up-4" style="width:100%;"><tbody><tr></tr></tbody></table>
```

### `<wrapper>`, `<h-line>`, `<center>`

- `<wrapper class="header">` → `<table class="header wrapper" align="center" style="width:100%;">` with a `.wrapper-inner` cell.
- `<h-line>` → a full-width single-cell table for a horizontal rule.
- `<center>` adds `align="center"` and `.float-center` to its element children (and `.float-center` to nested menu items).

### `<inky>`

Renders a bare `<tr>` (mirrors inky.js), useful inside hand-written tables.

### `<raw>`

Anything between `<raw>` and `</raw>` is passed through untouched (multi-line
supported). Raw blocks cannot be nested.

```html
<raw><% liquid_or_mso_conditional %></raw>
```

## Custom components

Register your own tag with a class that inherits from `Inky::Components::Base`
and implements `#transform(node, inner)`. You get the matched Nokogiri node
(full DOM access) and the already-transformed inner HTML; return the replacement
markup string.

```ruby
class Hr < Inky::Components::Base
  extend T::Sig

  sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
  def transform(node, _inner)
    klass = combine_classes(node, 'divider')
    %(<table class="#{klass}" role="presentation" style="width:100%;"><tbody><tr><td></td></tr></tbody></table>)
  end
end

Inky.configuration.register_component('hr-line', Hr)
```

The `sig` is recommended (and required if your app runs `srb tc`); a plain
`def transform(node, _inner)` without it also works at runtime.

```html
<hr-line class="muted"></hr-line>
```

Helper methods available from `Base`: `combine_classes`, `combine_attributes`,
`pass_through_attributes`, `class?`, `target_attribute`, `column_count`,
`container_width`.

Per-instance overrides (including replacing a built-in tag) are also possible:

```ruby
Inky::Core.new(components: { 'button' => MyButton }).release_the_kraken(source)
```

## Email-client compatibility policy

The generated markup targets the real-world client landscape as of 2026:

- **Outlook for Windows (Word engine)** — supported through its expected
  lifetime (~2029). MSO ghost tables/cells and `mso-*` properties keep layouts
  intact; the new Chromium-based Outlook is not yet the whole installed base.
- **Orange.fr (major FR webmail)** — degraded but functional: the markup never
  *depends* on `!important`, `border-radius`, `background-image`, flex, or grid,
  all of which Orange strips or ignores.
- **Gmail mobile** — strips most `<style>` blocks, so all critical layout is
  inline. Keep your enhancement CSS in a `<style>` block (inlined by your app's
  premailer for the classes Inky preserves).
- **Accessibility** — `role="presentation"` on every layout table; provide
  `alt` text and sufficient contrast in your own content.

The gem does not emit hard-coded colors, so app-side dark mode
(`prefers-color-scheme`, `[data-ogsc]`) works unhindered.

## Migrating from 1.x

- The rendered markup changed; re-record any email snapshots.
- The `foundation_emails` runtime dependency was removed. Add it to your own
  Gemfile if you still want Foundation's SCSS, or style the preserved class
  hooks yourself.
- Replace string-map custom components (`components: { tag: 'name' }`) with
  `register_component` (or class-valued `components:`).

See [`CHANGELOG.md`](CHANGELOG.md) for the full list.

## Development

```bash
bundle install
bundle exec rake test     # minitest
bundle exec rubocop
bundle exec srb tc        # Sorbet
```

## License

MIT. See [`LICENSE.txt`](LICENSE.txt).
