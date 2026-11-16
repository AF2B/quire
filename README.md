# quire

**Pages are functions. Sites are data.**

[![CI](https://github.com/AF2B/quire/actions/workflows/ci.yml/badge.svg)](https://github.com/AF2B/quire/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-af2b.github.io%2Fquire-0074D9)](https://af2b.github.io/quire/)
[![Pages](https://github.com/AF2B/quire/actions/workflows/pages.yml/badge.svg)](https://github.com/AF2B/quire/actions/workflows/pages.yml)
[![Release](https://img.shields.io/github/v/release/AF2B/quire?include_prereleases&label=release&color=0074D9)](https://github.com/AF2B/quire/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-0074D9)](LICENSE)
[![Common Lisp](https://img.shields.io/badge/Common%20Lisp-SBCL-0074D9)](https://www.sbcl.org/)
[![Status: preview](https://img.shields.io/badge/status-preview-333333)](CHANGELOG.md)

A static site generator in Common Lisp. Content is **data**, pages are
**functions**, HTML is written as S-expressions, and the REPL is the dev
server: redefine a layout and the browser reloads.

> A *quire* is a gathering of folded sheets that forms the pages of a book.

- Markdown with Lisp front matter, fenced code highlighted for Lisp
- Layouts are plain Lisp functions, looked up late, so they are live at the REPL
- Tags, section listings, RSS and Atom feeds and a sitemap out of the box
- Canonical link and Open Graph tags for shared links
- `quire check` finds broken internal links, for CI
- Deterministic output: same content in, same bytes out
- Dev server with live reload (server-sent events), rebuilds on file changes
- Single executable: `quire build`, `quire serve`, about 5 ms to start
- Default theme built on the Borba Design System (the generator itself is
  theme-agnostic)

Status: `0.1.0`, a public preview: the API may still change before 1.0.
SBCL only. License: MIT (see `LICENSE`); the bundled fonts are under the SIL
Open Font License (see `NOTICE.md`). Changes are listed in `CHANGELOG.md`.

Documentation: **<https://af2b.github.io/quire/>**. That site, guide included,
is built entirely with quire (the source is in `site/`). The screenshots below
show the demo site in `examples/demo/`.

![The demo site: home page](docs/screenshot-home.jpg)

![The demo site: a post with highlighted Lisp code](docs/screenshot-post.jpg)

## Quick start

Requirements: SBCL, ASDF, Quicklisp.

```bash
make binary                                   # bin/quire, a standalone executable
bin/quire build --site examples/demo/site.lisp --out public
bin/quire serve --site examples/demo/site.lisp
```

## A site

A site is a directory with a definition file and Markdown content:

```
site.lisp
content/
  index.md            ->  /
  about.md            ->  /about/
  posts/first.md      ->  /posts/first/
  img/logo.png        ->  /img/logo.png      (copied as bytes)
static/               ->  copied verbatim to the root
```

`site.lisp` sets `*site*`:

```lisp
(in-package #:quire-user)

(setf *site*
      (make-site :title "My site"
                 :description "One sentence about it."
                 :base-url "https://example.com"
                 :layouts (quire/theme-borba:layouts)
                 :steps (quire/theme-borba:steps)
                 :extra '(:nav (("Home" . "/") ("Posts" . "/posts/")))))
```

### Content files

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

| Key | Meaning |
|-----|---------|
| `:title` | Defaults to the file name, capitalized |
| `:date` | `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS[Z]`, UTC; makes the page a dated entry |
| `:tags` | List of strings; each gets a page under `/tags/` |
| `:layout` | Keyword; defaults to `:post` under `posts/`, else `:page` |
| `:path` | Overrides the URL path |
| `:draft` | `t` leaves the page out unless `--drafts` |
| `:lang` | Language of this page; defaults to the site's |
| `:image` | Share image for Open Graph and Twitter cards |
| `:description`, `:noindex`, `:hide-title` | Used by the theme and the sitemap |

The front matter is read with `*read-eval*` off, so it cannot run code.

### Layouts and steps

A layout is a function `(page site pages) -> string`. `page` carries the
rendered Markdown as its body, `pages` is every page of the site. Pass layouts
to `make-site` as symbols, not function objects, so redefining one takes effect:

```lisp
(defun my-layout (page site pages)
  (declare (ignore site pages))
  (format nil "<h1>~A</h1>~A" (getf (page-metadata page) :title) (page-body page)))

(make-site :title "T" :layouts '(:page my-layout))
```

A build is a list of steps `(page-map site) -> page-map`, run in order. The
defaults are `add-section-indexes`, `add-tag-pages`, `add-feed`,
`add-atom-feed`, `add-sitemap` and `apply-layouts` (always last). Add your own
anywhere before it: a step is the extension point, there is no separate plugin
system (see the guide).

## HTML output

The pages quire writes are plain, modern HTML5:

- `<!doctype html>`, a `lang` attribute, a viewport meta tag and a UTF-8
  charset
- Semantic landmarks (`header`, `nav`, `main`, `article`, `footer`), a skip
  link, `aria-current` on the active navigation entry and `<time datetime>`
  for dates
- An RSS alternate link when the site has dated pages
- Text and attributes escaped by default

You write layouts with [Spinneret](https://github.com/ruricolist/spinneret), so
HTML is S-expressions and any HTML5 element is available:

```lisp
(spinneret:with-html-string
  (:article
   (:header (:h1 "Title") (:time :datetime "2026-11-14" "14 Nov 2026"))
   (:figure (:picture (:source :srcset "a.webp" :type "image/webp")
                      (:img :src "a.png" :alt "A diagram"))
            (:figcaption "A diagram"))
   (:details (:summary "More") (:p "Hidden until opened."))
   (:dialog :open t (:p "Hello"))))
```

The test suite renders more than thirty elements, among them `article`,
`aside`, `audio`, `details`, `dialog`, `figure`, `hgroup`, `mark`, `meter`,
`nav`, `picture`, `progress`, `ruby`, `section`, `summary`, `template`, `time`
and `video`. Spinneret has no `<search>` or `<slot>` element; write those with
`(:raw "<search>...</search>")`.

In Markdown content, raw HTML passes through unchanged, so `<details>`,
`<picture>`, `<video>` and the rest work there too.

## REPL-driven development

```lisp
(asdf:load-system "quire/cli")            ; also loads the server and the theme
(load "examples/demo/site.lisp")

(defparameter *server*
  (quire/server:start-server (lambda () (quire:build-site quire:*site*))
                             :port 4000
                             :watch (quire:site-watched-directories quire:*site*)))

;; Edit and recompile a layout with C-c C-c, then nudge the open tabs:
(quire/server:reload-browsers *server*)

(quire/server:stop-server *server*)
```

Layouts run on every request, so a redefinition shows up without rebuilding.
Content changes are noticed by a poller (every 0.5 s) and trigger a rebuild and
a reload. A failed build is shown in the browser until you fix it.

## Errors are conditions

Quire signals typed conditions, all under `quire-error`, with restarts:

| Condition | Restarts |
|-----------|----------|
| `invalid-path` | `use-value` |
| `path-conflict` | `skip-page`; `keep-existing`, `replace-existing` for two pages at one path |
| `unknown-layout` | `use-value` |
| `front-matter-error`, `invalid-date` | none; the message names the file |
| `unsafe-output-directory` | none; `--clean` never deletes a directory quire did not create |

## Command line

```
quire build [--site FILE] [--out DIR] [--clean] [--drafts]
quire check [--site FILE] [--drafts]
quire serve [--site FILE] [--port N] [--host ADDR] [--drafts]
quire version | help
```

`quire check` builds the site and reports every internal link that leads
nowhere; it exits with `1` when there is one. Exit codes: `0` ok, `1` quire
error or broken links, `2` usage error, `70` internal error,
`130` interrupted. `--clean` empties the output directory first, but only when
it is new, empty or marked by a `.quire-output` file written by a previous
build.

## Development

```bash
make build         # strict build: any WARNING or STYLE-WARNING fails it
make test          # strict build, then the FiveAM suite
make binary        # bin/quire
make deps          # install third-party dependencies through Quicklisp
make sync-design   # re-copy tokens.css and fonts from ~/Documents/borba-design-system
```

Every push and pull request runs the strict build, the suite, builds the
executable and builds the demo site twice to check that the output is identical
(see `.github/workflows/ci.yml`). Every push to `main` also builds the product
site in `site/` with quire and publishes it to GitHub Pages (see
`.github/workflows/pages.yml`).

Systems: `quire` (core), `quire/theme-borba`, `quire/server`, `quire/cli`,
`quire/tests`. One package per file, exported symbols only.

Dependencies: 3bmd (+ code-blocks and tables extensions), alexandria, Spinneret
(theme only), Hunchentoot, bordeaux-threads, flexi-streams (server only),
FiveAM and usocket (tests only).

## Limits

- SBCL only; interrupt handling and `save-lisp-and-die` are SBCL-specific.
- Raw HTML in Markdown passes through unchanged (3bmd). Do not render content
  you do not trust.
- 3bmd is not strict CommonMark. Fenced code needs backticks, not tildes.
- Files whose name has no extension cannot be a site path and are skipped with
  a warning, except `CNAME` and `LICENSE`. Hidden files are ignored, except
  `.nojekyll` and `.well-known/`.
- The watcher polls; it does not use inotify. Very large content trees will
  make each poll slower.
- No image pipeline yet; i18n is a `:lang` per page, with no translation links.
- One-shot builds are not incremental; the dev server reuses unchanged Markdown.
