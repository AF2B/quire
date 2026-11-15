# quire

A static site generator in Common Lisp. Content is **data**, pages are
**functions**, HTML is written as S-expressions, and the REPL is the dev
server: redefine a layout and the browser reloads.

> A *quire* is a gathering of folded sheets that forms the pages of a book.

- Markdown with Lisp front matter, fenced code highlighted for Lisp
- Layouts are plain Lisp functions, looked up late, so they are live at the REPL
- Tags, section listings, RSS feed and sitemap out of the box
- Deterministic output: same content in, same bytes out
- Dev server with live reload (server-sent events), rebuilds on file changes
- Single executable: `quire build`, `quire serve`, about 5 ms to start
- Default theme built on the Borba Design System (the generator itself is
  theme-agnostic)

Status: `0.1.0`. SBCL only. License: not chosen yet.

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
defaults are `add-section-indexes`, `add-tag-pages`, `add-feed`, `add-sitemap`
and `apply-layouts` (always last). Add your own anywhere before it.

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
quire serve [--site FILE] [--port N] [--host ADDR] [--drafts]
quire version | help
```

Exit codes: `0` ok, `1` quire error, `2` usage error, `70` internal error,
`130` interrupted. `--clean` empties the output directory first, but only when
it is new, empty or marked by a `.quire-output` file written by a previous
build.

## Development

```bash
make build         # strict build: any WARNING or STYLE-WARNING fails it
make test          # strict build, then the FiveAM suite
make binary        # bin/quire
make sync-design   # re-copy tokens.css and fonts from ~/Documents/borba-design-system
```

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
- Files whose name has no extension (such as `CNAME`) cannot be a site path and
  are skipped with a warning; dot-files are ignored.
- The watcher polls; it does not use inotify. Very large content trees will
  make each poll slower.
- No incremental builds, i18n, image pipeline or plugin system yet.
