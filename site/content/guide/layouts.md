---
(:title "Layouts and steps"
 :description "Pages are functions, builds are pipelines.")
---

## Layouts

A layout is a function `(page site pages) -> string`. `page` carries the
rendered Markdown as its body, `site` is the site definition and `pages` is
every page of the site.

Pass layouts to `make-site` as symbols, not function objects, so redefining
one takes effect:

```lisp
(defun my-layout (page site pages)
  (declare (ignore site pages))
  (format nil "<h1>~A</h1>~A"
          (getf (page-metadata page) :title)
          (page-body page)))

(make-site :title "T" :layouts '(:page my-layout))
```

A page picks its layout with `:layout` in the front matter. A page whose
layout is not in the table signals `unknown-layout`, and the `use-value`
restart lets you supply one.

## Steps

A build is a list of steps `(page-map site) -> page-map`, run in order. The
defaults are:

| Step | Does |
|------|------|
| `add-section-indexes` | A listing page for each section that has dated pages and no `index.md` |
| `add-tag-pages` | One page per tag, plus `/tags/` |
| `add-feed` | `/feed.xml`, RSS 2.0, the latest 20 dated pages |
| `add-atom-feed` | `/atom.xml`, Atom 1.0, the same pages |
| `add-sitemap` | `/sitemap.xml` |
| `apply-layouts` | Turns every page into HTML; always last |

Add your own step anywhere before `apply-layouts`. A step returns a new page
map and never modifies the one it receives.

## Pages are data

A page has a path, a body, a metadata plist and a source. The body is text,
bytes or a function that quire calls when the page is written or served.
Because a page is data, adding one is a function call:

```lisp
(add-page page-map
          (make-page :path "/hello/"
                     :body "<h1>Hello</h1>"))
```

Next: [extending quire](../extending/).
