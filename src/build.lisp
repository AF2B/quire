(defpackage #:quire/build
  (:use #:cl)
  (:import-from #:quire/content
                #:read-content
                #:read-static-directory)
  (:import-from #:quire/atom
                #:add-atom-feed)
  (:import-from #:quire/feed
                #:add-feed)
  (:import-from #:quire/page-map
                #:merge-page-maps)
  (:import-from #:quire/site
                #:site-static-directories
                #:site-steps)
  (:import-from #:quire/sitemap
                #:add-sitemap)
  (:import-from #:quire/steps
                #:add-section-indexes
                #:add-tag-pages
                #:apply-layouts)
  (:export #:build-site
           #:default-steps
           #:run-steps))

(in-package #:quire/build)

(defun default-steps ()
  "Return the build steps used when a site does not set its own.

Each step is a symbol naming a function of a page map and a site that returns
a page map. Symbols, not function objects, so that redefining a step at the
REPL takes effect."
  (list 'add-section-indexes
        'add-tag-pages
        'add-feed
        'add-atom-feed
        'add-sitemap
        'apply-layouts))

(defun run-steps (steps page-map site)
  "Return the page map that results from applying STEPS in order.

STEPS: function designators, each called as (STEP PAGE-MAP SITE).
PAGE-MAP: the initial page map.
SITE: the site being built."
  (let ((current page-map))
    (dolist (step steps current)
      (setf current (funcall step current site)))))

(defun build-site (site)
  "Return the page map of SITE: its content, its static files and the steps.

Reading and the steps are pure with respect to the file system apart from
reading. Page bodies produced by layouts are functions resolved on demand.

SITE: the site to build."
  (run-steps (or (site-steps site) (default-steps))
             (apply #'merge-page-maps
                    (read-content site)
                    (mapcar #'read-static-directory
                            (site-static-directories site)))
             site))
