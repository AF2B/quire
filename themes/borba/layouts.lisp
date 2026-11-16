(defpackage #:quire/theme-borba
  (:use #:cl)
  (:import-from #:alexandria
                #:define-constant)
  (:import-from #:quire/atom
                #:+atom-path+)
  (:import-from #:quire/build
                #:default-steps)
  (:import-from #:quire/content
                #:page-source-name)
  (:import-from #:quire/dates
                #:format-iso-date)
  (:import-from #:quire/feed
                #:+feed-path+)
  (:import-from #:quire/languages
                #:language-prefix
                #:page-language)
  (:import-from #:quire/page
                #:page-body
                #:page-metadata
                #:page-path)
  (:import-from #:quire/site
                #:site-base-url
                #:site-description
                #:site-extra
                #:site-link
                #:site-posts-section
                #:site-title
                #:site-url)
  (:import-from #:quire/steps
                #:all-tags
                #:dated-pages
                #:newest-first
                #:pages-in-language
                #:pages-in-section
                #:pages-with-tag
                #:tag-url-path)
  (:import-from #:quire/theme-borba/assets
                #:add-theme-assets
                #:static-directory)
  (:import-from #:quire/theme-borba/i18n
                #:flag-sprite-html
                #:language-switcher-html
                #:localized-path
                #:multilingual-p
                #:page-lang
                #:ui)
  (:export #:about-layout
           #:add-theme-assets
           #:contact-layout
           #:home-layout
           #:index-layout
           #:layouts
           #:page-layout
           #:post-layout
           #:series-index-layout
           #:series-layout
           #:static-directory
           #:steps
           #:tag-layout
           #:tags-layout))

(in-package #:quire/theme-borba)

(defconstant +latest-posts-count+ 5
  "Posts listed under the hero of the home page.")

(defconstant +featured-posts-count+ 3
  "Posts shown as cards in the Start here section of the home page.")

(defconstant +toc-minimum-entries+ 2
  "Fewest headings that make a table of contents worth showing.")

(define-constant +tokens-css-path+ "/css/tokens.css"
  :test #'string=
  :documentation "Design tokens copied from the Borba Design System.")

(define-constant +theme-css-path+ "/css/quire-borba.css"
  :test #'string=
  :documentation "Stylesheet of the theme.")

(define-constant +logo-wordmark+ "BORBA"
  :test #'string=
  :documentation "The author's logo: the name in capitals, then a blue period.")

(define-constant +default-nav+ '((:home . "/"))
  :test #'equal
  :documentation "Navigation used when the site sets no :NAV.")

(define-constant +quire-address+ "https://github.com/AF2B/quire"
  :test #'string=
  :documentation "Where the footer points to credit the generator.")

(defun layouts ()
  "Return the plist of layout keywords the theme defines, for MAKE-SITE.

Values are symbols, so redefining a layout function at the REPL changes the
next render."
  (list :page 'page-layout
        :post 'post-layout
        :home 'home-layout
        :index 'index-layout
        :tag 'tag-layout
        :tags 'tags-layout
        :series 'series-layout
        :series-index 'series-index-layout
        :about 'about-layout
        :contact 'contact-layout))

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

(define-constant +absolute-url-prefix+ "http"
  :test #'string=
  :documentation "Start of an image address that is already absolute.")

(define-constant +card-with-image+ "summary_large_image"
  :test #'string=
  :documentation "Twitter card type used when the page has an image.")

(define-constant +card-without-image+ "summary"
  :test #'string=
  :documentation "Twitter card type used when the page has no image.")

(defun absolute-url (site address)
  "Return ADDRESS as an absolute URL on SITE.

An address that already starts with http is returned unchanged.

SITE: the site being built.
ADDRESS: an absolute URL or a URL path such as \"/img/cover.png\"."
  (if (eql 0 (search +absolute-url-prefix+ address))
      address
      (site-url site address)))

(defun social-meta-html (page site)
  "Return the canonical link and the Open Graph and Twitter card meta tags.

The canonical and og:url tags are written only when the site has a base URL.
The image comes from :IMAGE in the front matter, else from :IMAGE in the site's
extra options.

PAGE: the page being rendered.
SITE: the site being built."
  (let* ((metadata (page-metadata page))
         (url (when (plusp (length (site-base-url site)))
                (site-url site (page-path page))))
         (description (or (getf metadata :description)
                          (site-description site)))
         (image (let ((address (or (getf metadata :image)
                                   (getf (site-extra site) :image))))
                  (when address
                    (absolute-url site address))))
         (timestamp (getf metadata :timestamp)))
    (spinneret:with-html-string
      (when url
        (:link :rel "canonical" :href url))
      (:meta :property "og:type" :content (if timestamp "article" "website"))
      (:meta :property "og:site_name" :content (site-title site))
      (:meta :property "og:title" :content (document-title page site))
      (:meta :property "og:description" :content description)
      (when url
        (:meta :property "og:url" :content url))
      (when image
        (:meta :property "og:image" :content image))
      (when timestamp
        (:meta :property "article:published_time"
               :content (format-iso-date timestamp)))
      (:meta :name "twitter:card"
             :content (if image +card-with-image+ +card-without-image+)))))

(defun alternates-html (page site)
  "Return the link elements that point at the translations of PAGE.

Written only when the site has a base URL, because hreflang needs absolute
addresses.

PAGE: the page being rendered.
SITE: the site being built."
  (let ((translations (getf (page-metadata page) :translations)))
    (if (and translations (plusp (length (site-base-url site))))
        (spinneret:with-html-string
          (:link :rel "alternate"
                 :hreflang (page-language site page)
                 :href (site-url site (page-path page)))
          (loop for (code . path) in translations
                do (:link :rel "alternate"
                          :hreflang code
                          :href (site-url site path))))
        "")))

(defun page-by-path (pages path)
  "Return the page of PAGES at PATH, or NIL.

PAGES: a list of pages.
PATH: a URL path."
  (find path pages :key #'page-path :test #'string=))

(defun language-path (site page path)
  "Return PATH below the language prefix of PAGE.

SITE: the site being built.
PAGE: the page being rendered.
PATH: a site path such as \"/feed.xml\"."
  (localized-path site page path))

(defun existing-path (site page pages path)
  "Return PATH in the language of PAGE when the site has it, else the default.

The default-language PATH is the fallback, so a section that was not translated
still links somewhere. NIL when neither exists.

SITE: the site being built.
PAGE: the page being rendered.
PAGES: every page of the site.
PATH: the default-language path, such as \"/posts/\"."
  (let ((localized (language-path site page path)))
    (cond ((page-by-path pages localized) localized)
          ((page-by-path pages path) path))))

(defun feed-link-path (site page pages path)
  "Return the feed PATH in the language of PAGE when the site built it, else NIL.

SITE: the site being built.
PAGE: the page being rendered.
PAGES: every page of the site.
PATH: the default-language path of the feed."
  (existing-path site page pages path))

(defun current-p (page nav-path)
  "Return true when PAGE is NAV-PATH or lives below it.

PAGE: the page being rendered.
NAV-PATH: the URL path of a navigation entry."
  (let ((path (page-path page)))
    (or (string= path nav-path)
        (and (string/= nav-path "/")
             (>= (length path) (length nav-path))
             (string= nav-path path :end2 (length nav-path))))))

(defun nav-label (site page label)
  "Return the text of a navigation entry.

SITE: the site being built.
PAGE: the page being rendered.
LABEL: a string, or a keyword naming an interface string such as :POSTS."
  (if (keywordp label)
      (ui site page label)
      label))

(defun header-html (page site pages)
  "Return the HTML of the site header.

PAGE: the page being rendered.
SITE: the site being built.
PAGES: every page of the site."
  ;; The wordmark goes through variables: Spinneret inspects constants inside
  ;; its body at macroexpansion time, and not every implementation has the
  ;; value of a constant defined in the same file at that point.
  (let* ((wordmark +logo-wordmark+)
         (logo-label (format nil "~A, home" +logo-wordmark+))
         (default-nav +default-nav+)
         (home (language-path site page "/"))
         (rss (feed-link-path site page pages +feed-path+))
         (atom (feed-link-path site page pages +atom-path+))
         (navigation-label (ui site page :primary)))
    (spinneret:with-html-string
      (:header :class "site-header"
       (:div :class "wrap-wide bar"
        (:a :class "logo" :href (site-link site home)
            :aria-label logo-label
            wordmark
            (:span :class "dot" "."))
        (:nav :aria-label navigation-label
         (loop for (label . path) in (or (getf (site-extra site) :nav)
                                         default-nav)
               for target = (existing-path site page pages path)
               when target
                 do (:a :href (site-link site target)
                        :aria-current (when (current-p page target) "page")
                        (nav-label site page label))))
        (:div :class "tools"
         (when rss
           (:a :href (site-link site rss) "RSS"))
         (when atom
           (:a :href (site-link site atom) "Atom"))
         (:raw (language-switcher-html site page))))))))

(defun footer-html (page site pages)
  "Return the HTML of the site footer.

The Elsewhere column lists the :SOCIAL pairs of (LABEL . URL) from the site's
extra options.

PAGE: the page being rendered.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((wordmark +logo-wordmark+)
         (logo-label (format nil "~A, home" +logo-wordmark+))
         (quire +quire-address+)
         (home (language-path site page "/"))
         (social (getf (site-extra site) :social))
         (rss (feed-link-path site page pages +feed-path+))
         (atom (feed-link-path site page pages +atom-path+)))
    (spinneret:with-html-string
      (:footer :class "site-footer" :id "colophon"
       (:div :class "wrap-wide foot-top"
        (:div :class "foot-brand"
         (:a :class "logo" :href (site-link site home) :aria-label logo-label
             wordmark
             (:span :class "dot" "."))
         (:p (site-description site)))
        (when social
          (:div :class "foot-col"
           (:h2 :class "label" (ui site page :elsewhere))
           (:ul
            (loop for (label . address) in social
                  do (:li (:a :href address label (:span "↗")))))))
        (:div :class "foot-col"
         (:h2 :class "label" (ui site page :this-site))
         (:ul
          (when rss
            (:li (:a :href (site-link site rss) "RSS" (:span rss))))
          (when atom
            (:li (:a :href (site-link site atom) "Atom" (:span atom))))
          (:li (:a :href quire (ui site page :built-with) (:span "↗"))))))
       (:div :class "wrap-wide foot-base"
        (:span (site-title site))
        (:span (ui site page :built-with)))))))

(defun shell-html (page site pages main)
  "Return the full HTML document that wraps MAIN.

PAGE: the page being rendered.
SITE: the site being built.
PAGES: every page of the site.
MAIN: the HTML string placed inside the main element."
  (let ((rss (feed-link-path site page pages +feed-path+))
        (atom (feed-link-path site page pages +atom-path+)))
    (spinneret:with-html-string
      (:doctype)
      (:html :lang (page-lang site page)
       (:head
        (:meta :charset "utf-8")
        (:meta :name "viewport" :content "width=device-width, initial-scale=1")
        (:title (document-title page site))
        (:meta :name "description"
               :content (or (getf (page-metadata page) :description)
                            (site-description site)))
        (:raw (social-meta-html page site))
        (:raw (alternates-html page site))
        (:link :rel "stylesheet" :href (site-link site +tokens-css-path+))
        (:link :rel "stylesheet" :href (site-link site +theme-css-path+))
        (when rss
          (:link :rel "alternate"
                 :type "application/rss+xml"
                 :title (site-title site)
                 :href (site-link site rss)))
        (when atom
          (:link :rel "alternate"
                 :type "application/atom+xml"
                 :title (site-title site)
                 :href (site-link site atom))))
       (:body
        (:raw (flag-sprite-html site))
        (:a :class "skip" :href "#main" (ui site page :skip))
        (:raw (header-html page site pages))
        (:main :id "main" (:raw main))
        (:raw (footer-html page site pages)))))))

(defun date-html (page)
  "Return the time element for the date of PAGE, or an empty string.

PAGE: the page to inspect."
  (let ((timestamp (getf (page-metadata page) :timestamp)))
    (if timestamp
        (spinneret:with-html-string
          (:time :datetime (format-iso-date timestamp)
                 (format-iso-date timestamp)))
        "")))

(defun minutes-text (site page entry)
  "Return the reading time of ENTRY as \"9 min\", or NIL when it has none.

SITE: the site being built.
PAGE: the page being rendered, which sets the language.
ENTRY: the page whose reading time to show."
  (let ((minutes (getf (page-metadata entry) :reading-minutes)))
    (when minutes
      (format nil "~D ~A" minutes (ui site page :min)))))

(defun tags-html (site page tags)
  "Return the list of links to the pages of TAGS.

SITE: the site being built.
PAGE: the page being rendered, which sets the language of the tag pages.
TAGS: a list of tag strings."
  (let ((prefix (language-prefix site (page-language site page))))
    (spinneret:with-html-string
      (:ul :class "tags"
       (dolist (tag tags)
         (:li (:a :href (site-link site (tag-url-path tag prefix)) tag)))))))

(defun entries-html (site page entries)
  "Return the list of rows that links to each of ENTRIES.

SITE: the site being built.
PAGE: the page being rendered.
ENTRIES: the pages to list, already in display order."
  (spinneret:with-html-string
    (:div :class "rows"
     (dolist (entry entries)
       (:a :class "inv row" :href (site-link site (page-path entry))
        (:raw (date-html entry))
        (:span :class "ttl"
         (page-title entry)
         (when (getf (page-metadata entry) :description)
           (:span :class "sum" (getf (page-metadata entry) :description))))
        (:span :class "tags"
         (dolist (tag (getf (page-metadata entry) :tags))
           (:span :class "tag" tag)))
        (:span :class "rt" (or (minutes-text site page entry) "")))))))

(defun card-label (entry)
  "Return the small label above the title of the card of ENTRY.

ENTRY: the page shown as a card."
  (let ((metadata (page-metadata entry)))
    (or (getf metadata :kicker)
        (getf metadata :series)
        (first (getf metadata :tags))
        "")))

(defun cards-html (site page entries)
  "Return the grid of cards that links to each of ENTRIES.

SITE: the site being built.
PAGE: the page being rendered.
ENTRIES: the pages to show, in display order."
  (spinneret:with-html-string
    (:div :class "cards"
     (dolist (entry entries)
       (:a :class "inv card" :href (site-link site (page-path entry))
        (:span :class "label" (card-label entry))
        (:h3 (page-title entry))
        (when (getf (page-metadata entry) :description)
          ;; A span, not a p: Spinneret omits the optional </p>, and an open p
          ;; inside an a makes the parser mangle the next sibling.
          (:span :class "desc" (getf (page-metadata entry) :description)))
        (:span :class "meta"
         (format nil "~A~@[ / ~A~]"
                 (let ((timestamp (getf (page-metadata entry) :timestamp)))
                   (if timestamp (format-iso-date timestamp) ""))
                 (minutes-text site page entry))))))))

(defun progress-html (published total)
  "Return the row of blocks that shows how much of a series is published.

PUBLISHED: how many parts exist.
TOTAL: how many parts the series will have."
  (spinneret:with-html-string
    (:div :class "parts" :role "img"
          :aria-label (format nil "~D / ~D" published total)
     (loop for index from 1 to total
           do (:i :class (when (<= index published) "done"))))))

(defun series-cards-html (site page series-pages)
  "Return the grid of cards of the series pages SERIES-PAGES.

SITE: the site being built.
PAGE: the page being rendered.
SERIES-PAGES: pages with the :SERIES layout."
  (spinneret:with-html-string
    (:div :class "series"
     (dolist (entry series-pages)
       (let* ((metadata (page-metadata entry))
              (published (length (getf metadata :series-paths)))
              (total (getf metadata :series-total)))
         (:a :class "inv s" :href (site-link site (page-path entry))
          (:span :class "label"
           (format nil "~D ~A / ~D ~A"
                   total (ui site page :parts)
                   published (ui site page :published)))
          (:h3 (page-title entry))
          (:raw (progress-html published total))))))))

(defun section-heading-html (title note)
  "Return the ruled heading of a section of the home page.

TITLE: the section name.
NOTE: a short grey text on the right, or NIL."
  (spinneret:with-html-string
    (:div :class "section-head"
     (:h2 :class "label" title)
     (when note
       (:span :class "label muted" note)))))

(defun language-posts (site page pages)
  "Return the posts in the language of PAGE, newest first.

SITE: the site being built.
PAGE: the page being rendered.
PAGES: every page of the site."
  (newest-first
   (dated-pages (pages-in-section
                 (pages-in-language site pages (page-language site page))
                 (site-posts-section site)))))

(defun language-series (site page pages)
  "Return the series pages in the language of PAGE, sorted by title.

SITE: the site being built.
PAGE: the page being rendered.
PAGES: every page of the site."
  (sort (remove-if-not (lambda (candidate)
                         (eq :series (getf (page-metadata candidate) :layout)))
                       (pages-in-language site
                                          pages
                                          (page-language site page)))
        #'string<
        :key #'page-title))

(defun page-layout (page site pages)
  "Render PAGE as a plain page: title and body.

Set :HIDE-TITLE T in the front matter to drop the title.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:article :class "wrap prose"
                 (unless (getf (page-metadata page) :hide-title)
                   (:h1 (page-title page)))
                 (:raw (page-body page))))))

(defun toc-html (site page)
  "Return the table of contents of PAGE, or an empty string when it is short.

SITE: the site being built.
PAGE: the page being rendered; its :TOC lists (LEVEL ID TEXT)."
  (let ((toc (getf (page-metadata page) :toc)))
    (if (< (length toc) +toc-minimum-entries+)
        ""
        (spinneret:with-html-string
          (:aside :class "toc" :aria-label (ui site page :on-this-page)
           (:span :class "label muted" (ui site page :on-this-page))
           (loop for (level id text) in toc
                 do (:a :class (when (= level 3) "sub")
                        :href (format nil "#~A" id)
                        text)))))))

(defun series-crumb-html (site page pages)
  "Return the breadcrumb line above the title of a post.

SITE: the site being built.
PAGE: the post being rendered.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (section (getf metadata :section))
         (series-path (getf metadata :series-path))
         (series-page (and series-path (page-by-path pages series-path))))
    (spinneret:with-html-string
      (:p :class "label muted crumb"
       (when section
         (:a :href (site-link site (language-path site page
                                                  (format nil "/~A/" section)))
             (ui site page :posts)))
       (when series-page
         (:raw " / ")
         (:a :href (site-link site series-path) (page-title series-page))
         (:raw " / ")
         (format nil "~A ~D ~A ~D"
                 (ui site page :part)
                 (getf metadata :part)
                 (ui site page :of)
                 (getf metadata :series-total)))))))

(defun series-nav-html (site page pages)
  "Return the links to the previous and next part of the series of PAGE.

SITE: the site being built.
PAGE: the post being rendered.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (previous (let ((path (getf metadata :series-previous)))
                     (and path (page-by-path pages path))))
         (next (let ((path (getf metadata :series-next)))
                 (and path (page-by-path pages path)))))
    (if (or previous next)
        (spinneret:with-html-string
          (:nav :class "pn" :aria-label (ui site page :series)
           (if previous
               (:a :class "inv" :href (site-link site (page-path previous))
                (:span :class "label" (format nil "← ~A" (ui site page :previous)))
                (:span :class "t" (page-title previous)))
               (:span))
           (if next
               (:a :class "inv next" :href (site-link site (page-path next))
                (:span :class "label" (format nil "~A →" (ui site page :next)))
                (:span :class "t" (page-title next)))
               (:span))))
        "")))

(defun source-link-html (site page)
  "Return the link to the Markdown source of PAGE, or an empty string.

It needs :SOURCE-URL in the site's extra options: the address that file names
under the content directory are appended to.

SITE: the site being built.
PAGE: the page being rendered."
  (let ((base (getf (site-extra site) :source-url))
        (name (page-source-name site page)))
    (if (and base name)
        (spinneret:with-html-string
          (:a :class "label src"
              :href (format nil "~A/~A" (string-right-trim "/" base) name)
              (format nil "~A .md ↗" (ui site page :view-source))))
        "")))

(defun post-layout (page site pages)
  "Render PAGE as a post: table of contents, title, meta line, body and series.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (toc (toc-html site page))
         (minutes (getf metadata :reading-minutes)))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:div :class "wrap-wide post-wrap"
                   (:raw toc)
                   (:article :class "post"
                    (:raw (series-crumb-html site page pages))
                    (:h1 :class "post-title" (page-title page))
                    (when (getf metadata :description)
                      (:p :class "dek" (getf metadata :description)))
                    (:div :class "meta-row"
                     (:span :class "label" (:raw (date-html page)))
                     (when minutes
                       (:span :class "label"
                        (format nil "~D ~A" minutes (ui site page :min-read))))
                     (:raw (tags-html site page (getf metadata :tags)))
                     (:raw (source-link-html site page)))
                    (:div :class "prose" (:raw (page-body page)))
                    (:raw (series-nav-html site page pages))))))))

(defun hero-html (page site pages)
  "Return the hero of the home page.

With :HEADLINE in the front matter the hero is the editorial one: eyebrow,
headline with an accented ending, lead, buttons and the page body as a side
panel. Without it the hero shows the site title.

PAGE: the home page.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (headline (getf metadata :headline))
         (rss (feed-link-path site page pages +feed-path+))
         (cta (getf metadata :cta)))
    (spinneret:with-html-string
      (if headline
          (:section :class "wrap-wide hero editorial"
           (:div
            (when (getf metadata :eyebrow)
              (:span :class "label" (getf metadata :eyebrow)))
            (:h1 headline
                 (when (getf metadata :accent)
                   (:raw " ")
                   (:em (getf metadata :accent))))
            (:p :class "lead" (site-description site))
            (:div :class "btns"
             (when (and cta (existing-path site page pages (cdr cta)))
               (:a :class "btn primary"
                   :href (site-link
                          site (existing-path site page pages (cdr cta)))
                   (car cta)))
             (when rss
               (:a :class "btn outline" :href (site-link site rss)
                   (ui site page :subscribe)))))
           (:div :class "hero-aside" (:raw (page-body page))))
          (:section :class "hero wrap"
           (:h1 (site-title site) (:span :class "dot" "."))
           (:p :class "lead" (site-description site)))))))

(defun home-layout (page site pages)
  "Render PAGE as the home page: hero, featured posts, latest posts and series.

Posts marked :FEATURED T in their front matter fill the Start here cards.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((posts (language-posts site page pages))
         (latest (subseq posts 0 (min +latest-posts-count+ (length posts))))
         (featured (let ((chosen (remove-if-not
                                  (lambda (post)
                                    (getf (page-metadata post) :featured))
                                  posts)))
                     (subseq chosen 0 (min +featured-posts-count+
                                           (length chosen)))))
         (series (language-series site page pages))
         (editorial (getf (page-metadata page) :headline))
         (section-path (language-path
                        site page (format nil "/~A/" (site-posts-section site)))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:raw (hero-html page site pages))
                  (unless editorial
                    (:article :class "wrap prose" (:raw (page-body page))))
                  (:div :class "wrap-wide home"
                   (when featured
                     (:raw (section-heading-html
                            (ui site page :start-here)
                            (ui site page :start-here-note)))
                     (:raw (cards-html site page featured)))
                   (when latest
                     (:raw (section-heading-html (ui site page :latest) nil))
                     (:raw (entries-html site page latest))
                     (when (page-by-path pages section-path)
                       (:p :class "more"
                        (:a :class "label"
                            :href (site-link site section-path)
                            (format nil "~A (~D)"
                                    (ui site page :all-posts)
                                    (length posts))))))
                   (when series
                     (:raw (section-heading-html (ui site page :series) nil))
                     (:raw (series-cards-html site page series))))))))

(defun index-layout (page site pages)
  "Render PAGE as the listing of the dated pages of its section.

PAGE: the page to render.
SITE: the site being built.
PAGES: every page of the site."
  (let ((entries (newest-first
                  (dated-pages
                   (pages-in-section
                    (pages-in-language site pages (page-language site page))
                    (getf (page-metadata page) :section))))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "wrap-wide listing"
                   (:h1 (page-title page))
                   (:raw (page-body page))
                   (:raw (entries-html site page entries)))))))

(defun tag-layout (page site pages)
  "Render PAGE as the listing of the pages that carry its tag.

PAGE: the tag page; its :TAG metadata names the tag.
SITE: the site being built.
PAGES: every page of the site."
  (let ((entries (newest-first
                  (pages-with-tag
                   (pages-in-language site pages (page-language site page))
                   (getf (page-metadata page) :tag)))))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "wrap-wide listing"
                   (:p :class "label" (ui site page :tag))
                   (:h1 (page-title page))
                   (:raw (entries-html site page entries)))))))

(defun tags-layout (page site pages)
  "Render PAGE as the list of every tag.

PAGE: the page to render.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:section :class "wrap-wide listing"
                 (:h1 (page-title page))
                 (:raw (tags-html
                        site
                        page
                        (all-tags (pages-in-language
                                   site pages (page-language site page)))))))))

(defun series-layout (page site pages)
  "Render PAGE as one series: progress and the list of published parts.

PAGE: the series page; :SERIES-PATHS lists its parts in order.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (parts (remove nil (mapcar (lambda (path) (page-by-path pages path))
                                    (getf metadata :series-paths))))
         (total (getf metadata :series-total)))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:section :class "wrap-wide listing"
                   (:p :class "label" (ui site page :series))
                   (:h1 (page-title page))
                   (:raw (progress-html (length parts) total))
                   (:raw (entries-html site page parts)))))))

(defun series-index-layout (page site pages)
  "Render PAGE as the list of every series of its language.

PAGE: the page to render.
SITE: the site being built.
PAGES: every page of the site."
  (shell-html page site pages
              (spinneret:with-html-string
                (:section :class "wrap-wide listing"
                 (:h1 (page-title page))
                 (:raw (series-cards-html
                        site page (language-series site page pages)))))))

(defun facts-html (facts)
  "Return the definition list of FACTS.

FACTS: a list of (LABEL . VALUE) pairs of strings."
  (spinneret:with-html-string
    (:dl :class "facts"
     (loop for (label . value) in facts
           do (:div (:dt label) (:dd value))))))

(defun cv-button-html (site page)
  "Return the button that downloads the CV, or an empty string.

The address is :CV in the front matter of PAGE.

SITE: the site being built.
PAGE: the page being rendered."
  (let ((cv (getf (page-metadata page) :cv)))
    (if cv
        (spinneret:with-html-string
          (:a :class "btn outline" :href (site-link site cv)
              (ui site page :download-cv)))
        "")))

(defun about-layout (page site pages)
  "Render PAGE as the about page: photo and facts beside the story.

The front matter may set :PHOTO (an image path), :FACTS (a list of (LABEL .
VALUE) pairs), :CV (a path) and :KICKER (the small label above the title).

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (photo (getf metadata :photo))
         (facts (getf metadata :facts)))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:div :class "wrap-wide about"
                   (:aside :class "side"
                    (if photo
                        (:img :class "photo" :src (site-link site photo)
                              :alt (page-title page))
                        (:div :class "photo placeholder"))
                    (when facts
                      (:raw (facts-html facts)))
                    (:raw (cv-button-html site page)))
                   (:article :class "prose"
                    (:span :class "label"
                     (or (getf metadata :kicker) (ui site page :about)))
                    (:h1 :class "post-title" (page-title page))
                    (when (getf metadata :description)
                      (:p :class "dek" (getf metadata :description)))
                    (:raw (page-body page))))))))

(defun contact-layout (page site pages)
  "Render PAGE as the contact page: address, buttons and the body.

The address comes from :EMAIL in the front matter, else from :EMAIL in the
site's extra options. :CV is the path of the CV, and :CV-PREVIEW the path of an
image of it.

PAGE: the page to render; its body is the rendered Markdown.
SITE: the site being built.
PAGES: every page of the site."
  (let* ((metadata (page-metadata page))
         (email (or (getf metadata :email) (getf (site-extra site) :email)))
         (preview (getf metadata :cv-preview)))
    (shell-html page site pages
                (spinneret:with-html-string
                  (:div :class "wrap-wide contact"
                   (:article :class "prose"
                    (:span :class "label" (ui site page :contact))
                    (:h1 (page-title page))
                    (when (getf metadata :description)
                      (:p :class "dek" (getf metadata :description)))
                    (when email
                      (:div :class "mailbox"
                       (:div :class "head"
                        (:span :class "label muted" (ui site page :email)))
                       (:div :class "addr" email)))
                    (:div :class "btns"
                     (when email
                       (:a :class "btn primary"
                           :href (format nil "mailto:~A" email)
                           (ui site page :email-me)))
                     (:raw (cv-button-html site page)))
                    (:raw (page-body page)))
                   (when preview
                     (:aside :class "cv-preview"
                      (:img :src (site-link site preview)
                            :alt (ui site page :download-cv)))))))))
