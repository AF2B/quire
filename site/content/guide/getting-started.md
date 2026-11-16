---
(:title "Getting started"
 :description "Install quire and build the demo site.")
---

## Requirements

SBCL, ASDF and Quicklisp. quire runs on SBCL only.

## Build the executable

```bash
git clone https://github.com/AF2B/quire
cd quire
make deps      # install third-party dependencies through Quicklisp
make binary    # bin/quire, a standalone executable
```

## Build and serve a site

```bash
bin/quire build --site examples/demo/site.lisp --out public
bin/quire serve --site examples/demo/site.lisp
```

`build` writes the site to `public/`. `serve` starts the dev server on port
4000 with live reload.

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

The `:base-url` may include a path, as in `https://example.com/blog`: every
link the theme writes then starts with `/blog`.

Next: [content files](../content/).
