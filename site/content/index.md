---
(:title "quire"
 :layout :home
 :description "A static site generator in Common Lisp.")
---

quire turns a folder of Markdown into a static site. Content is **data**,
pages are **functions**, HTML is written as S-expressions, and the REPL is the
dev server: redefine a layout and the browser reloads.

```lisp
(defun post-layout (page site pages)
  (shell-html page site pages (render-post page)))
```

## Why quire

- **Layouts are plain Lisp functions**, looked up late: redefine one at the
  REPL and the next request uses it.
- **Deterministic output.** Same content in, same bytes out. Dates come from
  the content, never from the clock.
- **Errors are conditions** with restarts, not stack traces: a path conflict
  asks which page wins.
- **Batteries included:** tags, section listings, an RSS feed, a sitemap and a
  dev server with live reload.
- **One executable.** `quire build` and `quire serve`, about 5 ms to start.

## Try it

You need SBCL, ASDF and Quicklisp.

```bash
git clone https://github.com/AF2B/quire
cd quire
make binary
bin/quire serve --site examples/demo/site.lisp
```

Then read the [guide](guide/) to build your own site.

## Built with quire

This site is made entirely with quire: the pages are Markdown, the theme is
the default `quire/theme-borba`, and GitHub Actions builds it on every push
to `main`. The source is in the
[`site/`](https://github.com/AF2B/quire/tree/main/site) directory of the
repository.

quire is at `0.1.0`, a public preview: the API may change before 1.0. It is
released under the MIT license. Source and issues are on
[GitHub](https://github.com/AF2B/quire).
