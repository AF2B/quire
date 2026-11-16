---
(:title "Content"
 :description "Markdown files, front matter and URLs.")
---

Each file under `content/` becomes a page. `about.md` is served at `/about/`,
`posts/first.md` at `/posts/first/`, and `index.md` at `/`. Files that are not
Markdown, such as images, are copied as bytes. Everything under `static/` is
copied verbatim to the root of the site.

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
| `:description`, `:noindex`, `:hide-title` | Used by the theme and the sitemap |

## Dates

Dates are parsed and checked: `2026-02-30` is an error, not a wrong page.
They are always UTC and come from the content, never from the clock. They
order the lists, and they become the `pubDate` of the RSS feed, the `lastmod`
of the sitemap and the `datetime` of the `<time>` element.

## Markdown

Tables and fenced code are supported, and fenced Lisp code is highlighted.
Fences use backticks, not tildes. Raw HTML passes through unchanged.

Next: [layouts and steps](../layouts/).
