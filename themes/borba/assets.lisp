(defpackage #:quire/theme-borba/assets
  (:use #:cl)
  (:import-from #:quire/conditions
                #:path-conflict
                #:path-conflict-reason)
  (:import-from #:quire/content
                #:read-static-directory)
  (:import-from #:quire/page-map
                #:add-page
                #:keep-existing
                #:merge-page-maps
                #:page-map-pages)
  (:export #:add-theme-assets
           #:static-directory))

(in-package #:quire/theme-borba/assets)

(defun static-directory ()
  "Return the directory that holds the CSS and fonts of the theme."
  (asdf:system-relative-pathname "quire" "themes/borba/static/"))

(defun load-assets ()
  "Return the page map of the theme files.

Fails loudly when the directory is missing, because an empty theme would build
unstyled sites without any message."
  (let ((directory (static-directory)))
    (unless (uiop:directory-exists-p directory)
      (error "Theme static directory not found: ~A" directory))
    (read-static-directory directory)))

(defvar *assets* (load-assets)
  "Page map of the theme files, read once when the theme is loaded, so that an
executable saved with the theme does not need the source tree.")

(defun add-theme-assets (page-map site)
  "Return PAGE-MAP plus the CSS and fonts of the theme.

A file that PAGE-MAP already has wins over the theme file at the same path, so
a site can override any asset by placing its own in static/.

PAGE-MAP: the page map to extend.
SITE: the site being built; unused, part of the step protocol."
  (declare (ignore site))
  (let ((result (merge-page-maps page-map)))
    (handler-bind ((path-conflict
                     (lambda (condition)
                       (when (eq :same-output (path-conflict-reason condition))
                         (invoke-restart 'keep-existing)))))
      (dolist (page (page-map-pages *assets*) result)
        (add-page result page)))))
