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

(test pages-carry-canonical-and-open-graph-tags
  (let ((html (themed-page-html :base-url "https://example.com/blog")))
    (is-true (search "rel=canonical" html))
    (is-true (search "https://example.com/blog/x/" html))
    (is-true (search "og:type" html))
    (is-true (search "website" html))
    (is-true (search "og:title" html))
    (is-true (search "twitter:card" html))
    (is-false (search "og:image" html))))

(test pages-without-a-base-url-have-no-canonical-link
  (let ((html (themed-page-html)))
    (is-false (search "rel=canonical" html))
    (is-false (search "og:url" html))
    (is-true (search "og:title" html))))

(test front-matter-image-becomes-an-absolute-open-graph-image
  (let ((html (themed-page-html
               :base-url "https://example.com/blog"
               :front-matter "(:title \"T\" :image \"/img/cover.png\")")))
    (is-true (search "og:image" html))
    (is-true (search "https://example.com/blog/img/cover.png" html))
    (is-true (search "summary_large_image" html))))

(test dated-pages-are-articles-with-a-publication-time
  (let ((html (themed-page-html
               :base-url "https://example.com"
               :front-matter "(:title \"T\" :date \"2026-11-14\")")))
    (is-true (search "article:published_time" html))
    (is-true (search "2026-11-14" html))
    (is-true (search "article" (subseq html (search "og:type" html)
                                       (+ (search "og:type" html) 40))))))

(test a-page-can-override-the-site-language
  (is-true (search "<html lang=pt-BR>"
                   (themed-page-html :front-matter "(:title \"Oi\" :lang \"pt-BR\")")))
  (is-true (search "<html lang=en>" (themed-page-html))))

(test dated-sites-advertise-both-feeds
  (let ((html (themed-page-html
               :base-url "https://example.com"
               :front-matter "(:title \"T\" :date \"2026-11-14\")")))
    (is-true (search "application/rss+xml" html))
    (is-true (search "application/atom+xml" html))
    (is-true (search "/atom.xml" html))))

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

;;; Blog features: languages, series, tables of contents and the other layouts.

(defparameter *two-languages*
  '((:code "en" :name "English" :flag "gb")
    (:code "pt-br" :name "Português" :flag "br"))
  "The languages of the multilingual test sites.")

(defun write-front (root name front-matter body)
  "Write the content file NAME under ROOT with FRONT-MATTER and BODY."
  (write-text-file root (concatenate 'string "content/" name)
                   (format nil "---~%~A~%---~%~A" front-matter body)))

(defun blog-html (path files &key languages extra)
  "Build a site from FILES and return the HTML of the page at PATH.

FILES: a list of (NAME FRONT-MATTER BODY) for the content directory.
LANGUAGES: the :languages of the site, or NIL.
EXTRA: the :extra plist of the site."
  (with-temp-directory (root)
    (loop for (name front-matter body) in files
          do (write-front root name front-matter body))
    (let ((page-map (build-site (make-site :title "Blog"
                                           :description "Desc"
                                           :base-url "https://example.com"
                                           :root root
                                           :languages languages
                                           :layouts (layouts)
                                           :steps (steps)
                                           :extra extra))))
      (resolve-body (find-page page-map path)))))

(defun contains-p (needle haystack)
  "Return true when HAYSTACK contains NEEDLE."
  (and (search needle haystack) t))

(defparameter *translated-files*
  '(("about.md" "(:title \"About\")" "English")
    ("pt-br/about.md" "(:title \"Sobre\")" "Português")
    ("posts/a.md" "(:title \"Post A\" :date \"2026-01-01\")" "x")
    ("pt-br/index.md" "(:layout :home :title \"Início\")" "Oi"))
  "Content of a site in English and Brazilian Portuguese.")

(test a-one-language-site-has-no-language-switcher-or-flags
  (let ((html (themed-page-html)))
    (is-false (contains-p "class=lang" html))
    (is-false (contains-p "f-gb" html))))

(test the-language-switcher-links-translations-with-flags
  (let ((html (blog-html "/about/" *translated-files*
                         :languages *two-languages*)))
    (is-true (contains-p "class=lang" html))
    (is-true (contains-p "#f-br" html))
    (is-true (contains-p "href=\"/pt-br/about/\" lang=pt-br hreflang=pt-br" html))
    (is-true (contains-p "aria-current=true" html))))

(test a-page-without-a-translation-links-the-language-home
  (let ((html (blog-html "/posts/a/" *translated-files*
                         :languages *two-languages*)))
    (is-true (contains-p "href=\"/pt-br/\" lang=pt-br" html))))

(test translated-pages-declare-hreflang-alternates
  (let ((html (blog-html "/about/" *translated-files*
                         :languages *two-languages*)))
    (is-true (contains-p "hreflang=en" html))
    (is-true (contains-p "<link rel=alternate hreflang=pt-br" html))
    (is-true (contains-p "https://example.com/pt-br/about/" html))))

(test the-html-lang-and-interface-follow-the-page-language
  (let ((html (blog-html "/pt-br/about/" *translated-files*
                         :languages *two-languages*
                         :extra '(:nav ((:about . "/about/"))))))
    (is-true (contains-p "<html lang=pt-br>" html))
    (is-true (contains-p "Sobre</a>" html))
    (is-true (contains-p "Pular para o conteúdo" html))))

(test untranslated-navigation-falls-back-to-the-default-language
  (let ((html (blog-html "/pt-br/about/" *translated-files*
                         :languages *two-languages*
                         :extra '(:nav ((:posts . "/posts/")
                                        (:missing . "/nowhere/"))))))
    (is-true (contains-p "href=\"/posts/\"" html))
    (is-false (contains-p "/nowhere/" html))))

(test the-site-can-override-an-interface-string
  (let ((html (blog-html "/pt-br/"
                         (append *translated-files*
                                 '(("pt-br/posts/b.md"
                                    "(:title \"B\" :date \"2026-01-02\")"
                                    "y")))
                         :languages *two-languages*
                         :extra '(:strings (("pt-br" :latest "Novidades"))))))
    (is-true (contains-p "Novidades" html))))

(test the-footer-lists-social-links
  (let ((html (themed-page-html)))
    (is-false (contains-p "Elsewhere" html)))
  (let ((html (blog-html "/about/" *translated-files*
                         :extra '(:social (("GitHub" . "https://github.com/me"))))))
    (is-true (contains-p "Elsewhere" html))
    (is-true (contains-p "href=\"https://github.com/me\"" html))
    (is-true (contains-p "Built with quire" html))))

(defparameter *series-files*
  '(("posts/one.md"
     "(:title \"One\" :date \"2026-01-01\" :series \"The Series\" :part 1 :series-total 3 :description \"Lead text.\")"
     #.(format nil "## First~%~%x~%~%## Second~%~%y"))
    ("posts/two.md"
     "(:title \"Two\" :date \"2026-01-02\" :series \"The Series\" :part 2 :series-total 3)"
     "## Only"))
  "Two parts of a series of three.")

(test posts-show-toc-reading-time-and-lead
  (let ((html (blog-html "/posts/one/" *series-files*)))
    (is-true (contains-p "class=toc" html))
    (is-true (contains-p "href=#first" html))
    (is-true (contains-p "id=\"first\"" html))
    (is-true (contains-p "1 min read" html))
    (is-true (contains-p "class=dek>Lead text." html))))

(test a-short-post-has-no-toc
  (is-false (contains-p "class=toc" (blog-html "/posts/two/" *series-files*))))

(test series-posts-show-a-breadcrumb-and-neighbours
  (let ((one (blog-html "/posts/one/" *series-files*))
        (two (blog-html "/posts/two/" *series-files*)))
    (is-true (contains-p "Part 1 of 3" one))
    (is-true (contains-p "href=\"/series/the-series/\"" one))
    (is-true (contains-p "href=\"/posts/two/\"" one))
    (is-false (contains-p "Previous" one))
    (is-true (contains-p "href=\"/posts/one/\"" two))
    (is-true (contains-p "Previous" two))))

(test the-series-page-shows-progress-and-parts
  (let ((html (blog-html "/series/the-series/" *series-files*)))
    (is-true (contains-p "aria-label=\"2 / 3\"" html))
    (is-true (contains-p "class=done" html))
    (is-true (contains-p "One" html))
    (is-true (contains-p "Two" html))))

(test the-source-link-needs-a-source-url
  (is-false (contains-p "View source" (blog-html "/posts/one/" *series-files*)))
  (let ((html (blog-html "/posts/one/" *series-files*
                         :extra '(:source-url "https://github.com/me/blog/blob/main/content/"))))
    (is-true (contains-p "https://github.com/me/blog/blob/main/content/posts/one.md"
                         html))))

(test the-editorial-home-shows-featured-cards-and-the-series
  (let ((html (blog-html
               "/"
               '(("index.md"
                  "(:layout :home :eyebrow \"Common Lisp\" :headline \"Lisp, from the\" :accent \"inside.\" :cta (\"Start here\" . \"/posts/one/\"))"
                  #.(format nil "```~%CL-USER> 1~%```"))
                 ("posts/one.md"
                  "(:title \"One\" :date \"2026-01-01\" :featured t :series \"S\" :part 1)"
                  "x"))
               :extra '(:email "a@b.c"))))
    (is-true (contains-p "class=\"wrap-wide hero editorial\"" html))
    (is-true (contains-p "Lisp, from the" html))
    (is-true (contains-p "<em>inside.</em>" html))
    (is-true (contains-p "Start here" html))
    (is-true (contains-p "class=\"inv card\"" html))
    (is-true (contains-p "class=series" html))))

(test the-contact-layout-shows-the-address-and-buttons
  (let ((html (blog-html "/contact/"
                         '(("contact.md" "(:layout :contact :title \"Hire me\" :cv \"/cv.pdf\")" ""))
                         :extra '(:email "me@example.com"))))
    (is-true (contains-p "me@example.com" html))
    (is-true (contains-p "href=mailto:me@example.com" html))
    (is-true (contains-p "href=\"/cv.pdf\"" html))
    (is-true (contains-p "Download CV" html))))

(test the-about-layout-shows-facts-and-a-photo
  (let ((html (blog-html "/about/"
                         '(("about.md" "(:layout :about :title \"Me\" :photo \"/me.jpg\" :facts ((\"Focus\" . \"Lisp\")))" "Story"))
                         :extra nil)))
    (is-true (contains-p "src=\"/me.jpg\"" html))
    (is-true (contains-p "<dt>Focus" html))
    (is-true (contains-p "<dd>Lisp" html))
    (is-true (contains-p "Story" html))))

(test details-containers-and-footnotes-reach-the-page
  (let ((html (blog-html "/posts/one/"
                         '(("posts/one.md"
                            "(:title \"One\" :date \"2026-01-01\")"
                            #.(format nil "Text[^n].~%~%::: details-open Expansion~%x~%:::~%~%[^n]: A note.")))
                         :extra nil)))
    (is-true (contains-p "<details class=\"exp\" open>" html))
    (is-true (contains-p "class=\"footnotes\"" html))
    (is-true (contains-p "A note." html))))

(test the-language-feeds-are-advertised-for-the-page-language
  (let ((html (blog-html "/pt-br/"
                         '(("posts/a.md" "(:title \"A\" :date \"2026-01-01\")" "x")
                           ("pt-br/index.md" "(:layout :home)" "Oi")
                           ("pt-br/posts/b.md" "(:title \"B\" :date \"2026-01-02\")" "y"))
                         :languages *two-languages*)))
    (is-true (contains-p "/pt-br/feed.xml" html))
    (is-true (contains-p "/pt-br/atom.xml" html))))
