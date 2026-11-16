---
(:title "Content"
 :description "Markdown files, front matter and URLs.")
---

Each file under `content/` becomes a page. `about.md` is served at `/about/`,
`posts/first.md` at `/posts/first/`, and `index.md` at `/`. Files that are not
Markdown, such as images, are copied as bytes. Everything under `static/` is
copied verbatim to the root of the site. Files such as `CNAME`, `LICENSE`,
`.nojekyll` and everything under `.well-known/` are copied too; other hidden
files are ignored.

## Front matter

A file may start with a Lisp property list between `---` lines:

```markdown
---
(:title "Pages are functions"
 :date "2026-11-10"
 :tags ("design" "lisp")
 :description "Shown in listings and the feed.")
---

The body, in Markdown.
```

The front matter is read with `*read-eval*` off, so it cannot run code.

| Key | Meaning |
|-----|---------|
| `:title` | Defaults to the file name, capitalized |
| `:date` | `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS[Z]`, UTC; makes the page a dated entry |
| `:tags` | List of strings; each gets a page under `/tags/` |
| `:layout` | Keyword; defaults to `:post` under `posts/`, else `:page` |
| `:path` | Overrides the URL path |
| `:draft` | `t` leaves the page out unless `--drafts` |
| `:lang` | Language of this page, such as `"pt-BR"`; defaults to the site's |
| `:image` | Share image for Open Graph and Twitter cards; a URL or a site path |
| `:series`, `:part`, `:series-total` | Make the page part `:part` of the series named `:series`; see [the theme](../theme/) |
| `:featured` | `t` shows a post in the Start here cards of the home page |
| `:kicker` | Small label above a card or a title |
| `:description`, `:noindex`, `:hide-title` | Used by the theme and the sitemap |

## Dates

Dates are parsed and checked: `2026-02-30` is an error, not a wrong page.
They are always UTC and come from the content, never from the clock. They
order the lists, and they become the `pubDate` of the RSS feed, the `lastmod`
of the sitemap and the `datetime` of the `<time>` element.

## Markdown

Tables and fenced code are supported, and fenced Lisp code is highlighted.
Fences use backticks, not tildes. Raw HTML passes through unchanged. quire adds
three things on top of plain Markdown.

**Containers** wrap Markdown in an element. HTML blocks do not render Markdown
inside them, containers do:

```markdown
::: details Expansion of the macro
Any *Markdown*, including fenced code.
:::
```

`details` makes a collapsed `<details>`, `details-open` an expanded one, and
any other word makes a `<div>` with that class. Containers do not nest, and a
`:::` line inside fenced code is just text.

**Footnotes** use `[^id]` in the text and `[^id]: note` on its own line.
References are numbered in order of appearance and link to an ordered list at
the end of the page. A definition nobody references is dropped, and so is a
reference without a definition.

**Heading ids and tables of contents**: every `h2` and `h3` gets an `id` made
from its text, so `## Two halves` can be linked as `#two-halves`. The headings
are also stored as `:toc` in the page metadata, a list of `(LEVEL ID TEXT)`.
The default steps set `:reading-minutes` too, counting words outside code.

Next: [layouts and steps](../layouts/).
