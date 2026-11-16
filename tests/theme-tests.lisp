(defpackage #:quire/tests/theme
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/build
                #:build-site)
  (:import-from #:quire/files
                #:read-file-text)
  (:import-from #:quire/page
                #:resolve-body)
  (:import-from #:quire/page-map
                #:find-page)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:with-temp-directory
                #:write-text-file)
  (:import-from #:quire/theme-borba
                #:layouts
                #:static-directory
                #:steps))

(in-package #:quire/tests/theme)

(def-suite theme-suite
  :description "The Borba theme and its conformance to the design system."
  :in quire-suite)

(in-suite theme-suite)

(defun remove-comments (css)
  "Return CSS without its /* */ comments."
  (with-output-to-string (out)
    (loop with index = 0
          while (< index (length css))
          do (let ((start (search "/*" css :start2 index)))
               (cond ((null start)
                      (write-string css out :start index)
                      (setf index (length css)))
                     (t
                      (write-string css out :start index :end start)
                      (setf index (+ 2 (search "*/" css :start2 start)))))))))

(defun css-text ()
  "Return the text of the theme stylesheet, without its comments."
  (remove-comments
   (read-file-text (merge-pathnames "css/quire-borba.css"
                                    (static-directory)))))

(defun themed-page-html (&key (base-url "") (path "x.md") front-matter nav)
  "Build a one-page site and return the HTML of its page.

BASE-URL: public address of the site.
PATH: content file name.
FRONT-MATTER: the sexp between the fences, as a string.
NAV: navigation entries as (LABEL . PATH) conses, or NIL for the default."
  (with-temp-directory (root)
    (write-text-file root (concatenate 'string "content/" path)
                     (format nil "---~%~A~%---~%Body <b>text</b>"
                             (or front-matter "(:title \"Hello & bye\")")))
    (let ((page-map (build-site (make-site :title "Site"
                                           :description "Desc"
                                           :base-url base-url
                                           :root root
                                           :layouts (layouts)
                                           :steps (steps)
                                           :extra (and nav (list :nav nav))))))
      (resolve-body (find-page page-map "/x/")))))

(test document-is-a-complete-html5-page
  (let ((html (themed-page-html)))
    (is-true (search "<!doctype html>" (string-downcase html)))
    (is-true (search "<html lang=en>" html))
    (is-true (search "<meta charset=utf-8>" html))
    (is-true (search "name=viewport" html))
    (is-true (search "<title>Hello &amp; bye — Site</title>" html))
    (is-true (search "Body <b>text</b>" html))))

(test stylesheets-honor-the-base-path
  (let ((html (themed-page-html :base-url "https://example.com/blog")))
    (is-true (search "/blog/css/tokens.css" html))
    (is-true (search "/blog/css/quire-borba.css" html))))

(test layouts-written-with-spinneret-can-use-modern-html-elements
  (dolist (tag '(:article :aside :audio :canvas :data :datalist :details
                 :dialog :figcaption :figure :footer :header :hgroup :main
                 :mark :menu :meter :nav :output :picture :progress :rp :rt
                 :ruby :section :source :summary :template :time :track
                 :video :wbr))
    (let ((html (eval `(spinneret:with-html-string (,tag "x")))))
      (is-true (search (format nil "<~(~A~)" tag) html)
               "~A should render" tag))))

(test output-uses-semantic-landmarks-and-accessibility-hooks
  (let ((html (themed-page-html)))
    (dolist (needle '("<header" "<nav aria-label=Primary" "<main id=main"
                      "<article" "<footer" "class=skip"))
      (is-true (search needle html) "~A should be in the page" needle))))

(test header-logo-is-the-borba-wordmark-whatever-the-site-title
  (let ((html (themed-page-html)))
    (is-true (search "aria-label=\"BORBA, home\">BORBA<span" html))
    (is-true (search "class=dot>.</span></a>" html))
    (is-false (search "aria-label=\"Site" html))))

(test navigation-marks-the-current-page
  (let ((html (themed-page-html :nav '(("Home" . "/") ("This" . "/x/")))))
    (is-true (search "aria-current=page>This" html))
    (is-false (search "aria-current=page>Home" html))))

(test theme-ships-the-design-system-files
  (let ((tokens (read-file-text (merge-pathnames "css/tokens.css"
                                                 (static-directory)))))
    (is-true (search "--background: 220 100% 3%;" tokens))
    (is-true (search "--radius: 0rem;" tokens))
    (dolist (font '("Inter.ttf" "JetBrainsMono.ttf" "PlayfairDisplay.ttf"))
      (is-true (probe-file (merge-pathnames (concatenate 'string "fonts/" font)
                                            (static-directory)))
               "~A should be vendored" font))))

(test stylesheet-follows-the-design-rules
  (let ((css (css-text)))
    (is-false (search "box-shadow" css) "no shadows")
    (is-false (search "gradient" css) "no gradients")
    (is-false (search "text-shadow" css) "no shadows")
    (is-true (search "border-radius: 0;" css))
    (is-true (search "1px solid hsl(var(--border))" css))
    (is-true (search "var(--font-mono)" css))
    (is-true (search "var(--font-serif)" css))
    (is-true (search "var(--terminal-bg)" css))
    (is-true (search "outline: 2px solid hsl(var(--ring))" css))))

(test stylesheet-has-no-rounded-corners-or-hard-coded-palette
  (let ((css (css-text)))
    (loop for position = (search "border-radius" css)
            then (search "border-radius" css :start2 (1+ position))
          while position
          do (is (string= "border-radius: 0;" css
                          :start2 position
                          :end2 (+ position (length "border-radius: 0;")))
                 "every radius must be zero"))
    (is-false (search "#" css)
              "colors must come from tokens, not hex literals")))
