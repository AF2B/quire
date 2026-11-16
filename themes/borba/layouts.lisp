(defpackage #:quire/theme-borba
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/build
                #:default-steps)
  (:import-from #:quire/dates
                #:format-iso-date)
  (:import-from #:quire/feed
                #:+feed-path+)
  (:import-from #:quire/page
                #:page-body
                #:page-metadata
                #:page-path)
  (:import-from #:quire/site
                #:site-description
                #:site-extra
                #:site-language
                #:site-link
                #:site-posts-section
                #:site-title)
  (:import-from #:quire/steps
                #:all-tags
                #:dated-pages
                #:newest-first
                #:pages-in-section
                #:pages-with-tag
                #:tag-url-path)
  (:import-from #:quire/theme-borba/assets
                #:add-theme-assets
                #:static-directory)
  (:export #:add-theme-assets
           #:home-layout
           #:index-layout
           #:layouts
           #:page-layout
           #:post-layout
           #:static-directory
           #:steps
           #:tag-layout
           #:tags-layout))

(in-package #:quire/theme-borba)

(defconstant +latest-posts-count+ 5
  "Posts listed under the hero of the home page.")

(define-constant +tokens-css-path+ "/css/tokens.css"
  :test #'string=
  :documentation "Design tokens copied from the Borba Design System.")

(define-constant +theme-css-path+ "/css/quire-borba.css"
  :test #'string=
  :documentation "Stylesheet of the theme.")

(define-constant +logo-wordmark+ "BORBA"
  :test #'string=
  :documentation "The author's logo: the name in capitals, then a blue period.")

(define-constant +default-nav+ '(("Home" . "/"))
  :test #'equal
  :documentation "Navigation used when the site sets no :NAV.")

(defun layouts ()
  "Return the plist of layout keywords the theme defines, for MAKE-SITE.

Values are symbols, so redefining a layout function at the REPL changes the
next render."
  (list :page 'page-layout
        :post 'post-layout
        :home 'home-layout
        :index 'index-layout
        :tag 'tag-layout
        :tags 'tags-layout))

(defun steps ()
  "Return the default build steps plus the one that adds the theme assets."
  (cons 'add-theme-assets (default-steps)))

(defun page-title (page)
  "Return the title of PAGE.

PAGE: the page to inspect."
  (getf (page-metadata page) :title))

(defun document-title (page site)
  "Return the text of the title element for PAGE on SITE.

PAGE: the page being rendered.
SITE: the site being built."
  (if (string= "/" (page-path page))
      (site-title site)
      (format nil "~A — ~A" (page-title page) (site-title site))))

(defun feed-present-p (pages)
  "Return true when PAGES includes the generated feed.

PAGES: every page of the site."
  (find +feed-path+ pages :key #'page-path :test #'string=))

(defun current-p (page nav-path)
  "Return true when PAGE is NAV-PATH or lives below it.

PAGE: the page being rendered.
NAV-PATH: the URL path of a navigation entry."
  (let ((path (page-path page)))
    (or (string= path nav-path)
        (and (string/= nav-path "/")
             (>= (length path) (length nav-path))
             (string= nav-path path :end2 (length nav-path))))))

(defun header-html (page site)
  "Return the HTML of the site header.

PAGE: the page being rendered.
SITE: the site being built."
  (spinneret:with-html-string
    (:header :class "site-header"
     (:div :class "wrap bar"
      (:a :class "logo" :href (site-link site "/")
          :aria-label (format nil "~A, home" +logo-wordmark+)
          +logo-wordmark+
          (:span :class "dot" "."))
      (:nav :aria-label "Primary"
       (loop for (label . path) in (or (getf (site-extra site) :nav)
                                       +default-nav+)
             do (:a :href (site-link site path)
                    :aria-current (when (current-p page path) "page")
                    label)))))))

(defun footer-html (site)
  "Return the HTML of the site footer.

SITE: the site being built."
  (spinneret:with-html-string
    (:footer :class "site-footer"
     (:div :class "wrap"
      (:span (site-title site))
      " · Built with quire"))))

(defun shell-html (page site pages main)
  "Return the full HTML document that wraps MAIN.

PAGE: the page being rendered.
SITE: the site being built.
PAGES: every page of the site.
MAIN: the HTML string placed inside the main element."
  (spinneret:with-html-string
    (:doctype)
    (:html :lang (site-language site)
     (:head
      (:meta :charset "utf-8")
      (:meta :name "viewport" :content "width=device-width, initial-scale=1")
      (:title (document-title page site))
      (:meta :name "description"
             :content (or (getf (page-metadata page) :description)
                          (site-description site)))
      (:link :rel "stylesheet" :href (site-link site +tokens-css-path+))
      (:link :rel "stylesheet" :href (site-link site +theme-css-path+))
      (when (feed-present-p pages)
        (:link :rel "alternate"
               :type "application/rss+xml"
               :title (site-title site)
               :href (site-link site +feed-path+))))
     (:body
      (:a :class "skip" :href "#main" "Skip to content")
      (:raw (header-html page site))
      (:main :id "main" (:raw main))
      (:raw (footer-html site))))))

(defun date-html (page)
  "Return the time element for the date of PAGE, or an empty string.

PAGE: the page to inspect."
  (let ((timestamp (getf (page-metadata page) :timestamp)))
    (if timestamp
        (spinneret:with-html-string
          (:time :datetime (format-iso-date timestamp)
                 (format-iso-date timestamp)))
        "")))

(defun entries-html (site pages)
  "Return the list of entries that links to each of PAGES.

SITE: the site being built.
PAGES: the pages to list, already in display order."
  (spinneret:with-html-string
    (:ul :class "entries"
     (dolist (page pages)
       (:li
        (:raw (date-html page))
        (:a :class "title" :href (site-link site (page-path page))
            (page-title page))
        (when (getf (page-metadata page) :description)
          (:p :class "summary" (getf (page-metadata page) :description))))))))

(defun tags-html (site tags)
  "Return the list of links to the pages of TAGS.

SITE: the site being built.
TAGS: a list of tag strings."
  (spinneret:with-html-string
    (:ul :class "tags"
     (dolist (tag tags)
       (:li (:a :href (site-link site (tag-url-path tag)) tag))))))

(defun page-layout (page site pages)
  "Render PAGE as a plain page: title and body.

Set :HIDE-TITLE T in the front matter to drop the title.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:article :class "wrap"
                 (unless (getf (page-metadata page) :hide-title)
                   (:h1 (page-title page)))
                 (:raw (page-body page))))))

(defun post-layout (page site pages)
  "Render PAGE as a post: date, serif title, body and tags.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:article :class "wrap post"
                 (:p :class "label" (:raw (date-html page)))
                 (:h1 :class "post-title" (page-title page))
                 (:raw (page-body page))
                 (:raw (tags-html site (getf (page-metadata page) :tags)))))))

(defun home-layout (page site pages)
  "Render PAGE as the home page: hero, body and the latest posts.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((posts (newest-first
                 (dated-pages (pages-in-section pages
                                                (site-posts-section site)))))
         (latest (subseq posts 0 (min +latest-posts-count+ (length posts)))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "hero wrap"
                   (:h1 (site-title site) (:span :class "dot" "."))
                   (:p :class "lead" (site-description site)))
                  (:article :class "wrap" (:raw (page-body page)))
                  (when latest
                    (:section :class "wrap"
                     (:h2 "Latest")
                     (:raw (entries-html site latest))))))))

(defun index-layout (page site pages)
  "Render PAGE as the listing of the dated pages of its section.

PAGE: the page to render.
SITE: the site being built.
PAGES: every page of the site."
  (let ((entries (newest-first
                  (dated-pages (pages-in-section
                                pages
                                (getf (page-metadata page) :section))))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "wrap"
                   (:h1 (page-title page))
                   (:raw (page-body page))
                   (:raw (entries-html site entries)))))))

(defun tag-layout (page site pages)
  "Render PAGE as the listing of the pages that carry its tag.

PAGE: the tag page; its :TAG metadata names the tag.
SITE: the site being built.
PAGES: every page of the site."
  (let ((entries (newest-first
                  (pages-with-tag pages (getf (page-metadata page) :tag)))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "wrap"
                   (:p :class "label" "Tag")
                   (:h1 (page-title page))
                   (:raw (entries-html site entries)))))))

(defun tags-layout (page site pages)
  "Render PAGE as the list of every tag.

PAGE: the page to render.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:section :class "wrap"
                 (:h1 (page-title page))
                 (:raw (tags-html site (all-tags pages)))))))
