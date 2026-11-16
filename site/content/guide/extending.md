---
(:title "Extending quire"
 :description "Write your own build step: quire has no plugin system because a step is one.")
---

quire has no plugin system, and needs none. A build is a list of **steps**,
each one a function `(page-map site) -> page-map`. Tags, the feeds, the
sitemap and the layouts are all steps, and so is anything you add.

## A step

A step receives the page map and the site, and returns a page map. It may add
pages, replace pages or leave them alone. It never modifies the map it
receives. This one estimates the reading time of every dated page:

```lisp
(defconstant +words-per-minute+ 200
  "Reading speed used to estimate the reading time.")

(defun reading-minutes (page)
  "Return the minutes PAGE takes to read, at least one."
  (max 1 (ceiling (1+ (count #\Space (page-body page))) +words-per-minute+)))

(defun add-reading-time (page-map site)
  "Return PAGE-MAP with :READING-MINUTES in the metadata of every dated page."
  (declare (ignore site))
  (let ((result (make-page-map)))
    (dolist (page (page-map-pages page-map) result)
      (add-page result
                (if (getf (page-metadata page) :timestamp)
                    (copy-page page
                               :metadata (list* :reading-minutes
                                                (reading-minutes page)
                                                (page-metadata page)))
                    page)))))
```

A layout can then read `(getf (page-metadata page) :reading-minutes)`.

## Registering it

Put the step in the site's `:steps`, before `apply-layouts`, which must stay
last because it wraps every page in its layout:

```lisp
(let ((steps (quire/theme-borba:steps)))
  (make-site :title "My site"
             :layouts (quire/theme-borba:layouts)
             :steps (append (butlast steps)
                            '(add-reading-time)
                            (last steps))))
```

Pass the step as a symbol, not a function object, so that redefining it at the
REPL takes effect on the next build.

## What a step can do

- **Add pages**: use `add-page` on a fresh map, or `with-added-pages`, which
  copies the map and signals `path-conflict` with its restarts when a path is
  taken. The tag pages and the feeds work this way.
- **Rewrite pages**: `copy-page` returns a new page with some slots replaced.
- **Read the site**: `site-title`, `site-base-url`, `site-extra` and the other
  readers of the site object. Put your own options under `:extra`.

Because a page is data and a step is a function, a step is easy to test: build
a small page map, call the step and check the result.

Next: [HTML output](../html/).
