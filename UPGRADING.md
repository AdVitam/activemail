# Upgrading to ActiveMail 2.1

## Gemfile

```ruby
gem 'activemail', '~> 2.1'
```

## Outer gutter

Rows now keep content off the screen edge: the first and last column of a row
get a 16px (`container_gutter`) border-box padding on their outer side, inlined
like every other framework rule. Columns still sum to `container_width`; the
text area is 16px narrower on each side.

- To keep edge-to-edge columns: `config.tokens.spacing :container_gutter, '0px'`
  (or `$am-container-gutter: 0`).
- Content you padded by hand to avoid the edge now has the padding twice:
  remove it.
- A nested row does not repeat the outer gutter. The `.columns.first.last` SCSS
  rule is gone; ejected `_grid.scss` copies (`activemail:styles`) must be
  re-ejected.

## Outlook markup

- Conditional comments are `<!--[if mso]>` (`mso` alone targets Outlook
  for Windows). Tests matching `[if mso | IE]` must change.
- Each column ghost cell wraps its column in a `<table><tr>`. A nested column
  is sized against the content box of its enclosing column: `large="6"` in a
  lone `large="6"` is 134px (300px minus two 16px gutters, halved), not 300px.

## Buttons

- The fill and the radius are on the cell, not on the `<a>`. The `<a>` carries
  `display:inline-block`, `font-family` (the `body` font token) and
  `line-height:1.25`; the cell gets `mso-padding-alt`.
- A dark-mode override of the button fill must target `table td`, not `a`.

## Center

`<center>` no longer adds `align="center"` and `.float-center` to its children
(nor to nested menu items): it renders one `<center align="center">` and leaves
its content as written. Put `class="float-center"` or `align="center"` on the
children that need it.

## Layouts

The `<head>` of the default layout moved to `layouts/activemail/_document_head`,
with `<title><%= message.subject %></title>`. The generated layouts
(`activemail:install`, `--haml`, `--slim`) render that partial and the `_head`
and `_footer` partials: regenerate yours or add the `<title>`. The partial reads
`message`, so it only renders inside a mailer view.

## Quality

New built-in rules flag emails that passed before: `title`, `anchor_href`,
`placeholder`, `unsupported_color`, `text_entities`. Disable any with
`Guard.new(disable: [...])`.

A `NullMail` (a mailer that returned without sending) is now a `declined`
violation, in `Guard`, `render_all`, `assert_email_quality`,
`assert_quality_for_all_previews` and `be_a_valid_email`. List the previews that
decline on purpose:

```ruby
ActiveMail::Quality.configure { |c| c.allow_declined = %w[reminder_mailer#maybe_skipped] }
```

or pass `allow_declined: true` to `Guard#violations`, `Guard#valid?`,
`assert_email_quality` and `be_a_valid_email`.

---

# Upgrading to ActiveMail 2.0

## Gemfile

```ruby
gem 'activemail', '~> 2.0'
```

## Inlining

The delivery interceptor is gone: each email is transpiled and inlined once,
when the mailer renders an inky HTML template.

- Remove `config.register_inline_interceptor` from your initializer.
- If you ran another inliner (premailer-rails) next to ActiveMail with
  `config.inliner = :null`, drop that inliner and the `:null` setting: ActiveMail
  now inlines the whole body, layout included.
- Inliner failures still raise `ActiveMail::Inliner::Error` (now a subclass of
  `ActiveMail::Error`).

## Layouts

Ejected or hand-written layouts must embed the stylesheets with the helper and
drop `stylesheet_link_tag` (Premailer strips it, so it never styled anything):

```erb
<%# before %>
<%= stylesheet_link_tag "emails/emails" %>
<%= activemail_inline_styles %>

<%# after %>
<%= activemail_inline_styles "emails/emails" %>
```

A missing or empty asset now raises `ActiveMail::StylesheetNotFound` instead of
logging a warning; inside a view it surfaces as the `#cause` of
`ActionView::Template::Error`.

## SCSS

The framework uses the Sass module system. Replace `@import` and variables
declared before it with `@use … with (…)`; a variable declared before the
`@use` is no longer read.

```scss
// before
$am-button-secondary-color: #264653;
@import "activemail/activemail";

// after
@use "activemail/activemail" with (
  $am-button-secondary-color: #264653
);
```

- Renamed: `$am-button-color` → `$am-button-primary-color`,
  `$am-info-box-bg` → `$am-info-box-background`.
- Prefer Ruby tokens (`secondary_text`, `secondary_border`, `info_box_*`, …):
  they now reach both the inline styles and the stylesheet, so SCSS overrides of
  the button/info-box variables are rarely needed.
- `$am-breakpoint` defaults to the container width (600px) instead of 596px.

## Buttons

`<button>` and `<cta>` share one rendering, styled inline from the tokens.

- CSS targeting the old markup (`<center>`, `.expander` cell inside
  `.button.expand`) no longer matches; style buttons through tokens.
- A dark-mode override must use `!important` to beat the inline styles.
- A `<button>` without `href` renders its label in a `<span>`.

## Components

- The `<inky>` tag is removed.
- `inner` is an opaque slot: interpolate it exactly once and never parse or
  alter it.
- `IGNORED_ON_PASSTHROUGH`, `combine_attributes`, `pass_through_attributes`,
  `bulletproof_button_table` and `BUTTON_PADDING` are removed. Use
  `root_attributes(node, classes:, layout_style:)` and override the private
  `consumed_attributes` to list the attributes your component reads; a
  component whose root is a `TABLE_RESET` table inherits from
  `ActiveMail::Components::TableComponent`.
- A component must output `inner` exactly once (or have no children):
  otherwise `ActiveMail::Error` is raised instead of silently dropping content.
  Self-closing `<h-line/>`/`<spacer/>` are not valid HTML4 and swallow their
  following siblings; write `<h-line></h-line>`.
- `id`, `aria-*`, `data-*` and other attributes now pass through on every
  built-in component. On tables carrying `TABLE_RESET`, the component's
  `role="presentation"` wins over the author's `role`.
- `ActiveMail::Core.new` only takes keywords (`config:`, `components:`,
  `column_count:`, `container_width:`). For plain transpilation prefer the
  memoized `ActiveMail.configuration.core`.
- Integer settings (`column_count`, `container_width`) raise `TypeError` for a
  non-Integer and `ArgumentError` for a non-positive value. Numeric attributes
  are parsed in strict base 10.

## Quality

- `output_dir` must be relative, inside `Rails.root` (symlinks resolved), and
  neither `.` nor contain `..`. `render_all` marks it with an
  `.activemail_previews` file and refuses to clean an existing, non-empty
  directory without that marker: empty your previous output directory once.
- `PreviewRenderer.render` is removed.
- `RenderAll.new(root:, config:)` replaces `output_root:`.
- Rendered files and failures carry the locale when it differs from the
  default (`welcome.fr.html`, `preview#email [fr]`).
- `Guard#violations` and `assert_email_quality` accept a `Mail::Message` (HTML
  plus message rules) or an HTML string. New built-in rules may flag existing
  emails: `translation_missing`, `translation_missing_text`, `single_root`,
  `html_part_present`, `text_part_present`, `text_part_plain`. Disable any with
  `Guard.new(disable: [...])`.
- Host-specific checks move to `Guard.new(rules: [Quality::Rule.html(...)])`.
