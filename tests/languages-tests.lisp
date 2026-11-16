(defpackage #:quire/tests/languages
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/atom
                #:add-atom-feed)
  (:import-from #:quire/content
                #:page-source-name
                #:read-content)
  (:import-from #:quire/dates
                #:parse-date)
  (:import-from #:quire/feed
                #:add-feed)
  (:import-from #:quire/languages
                #:add-translations
                #:language-codes
                #:language-prefix
                #:localize-path
                #:page-language
                #:split-language-path)
  (:import-from #:quire/page
                #:make-page
                #:page-metadata)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map)
  (:import-from #:quire/site
                #:make-site
                #:site-languages)
  (:import-from #:quire/steps
                #:add-section-indexes
                #:add-tag-pages)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:with-temp-directory
                #:write-text-file))

(in-package #:quire/tests/languages)

(def-suite languages-suite
  :description "Languages: prefixes, translations and per-language pages."
  :in quire-suite)

(in-suite languages-suite)

(defun site-with (&rest languages)
  "Return a site in English that also has LANGUAGES, as codes."
  (make-site :title "T"
             :base-url "https://example.com"
             :languages (cons '(:code "en" :name "English")
                              (mapcar (lambda (code) (list :code code :name code))
                                      languages))))

(defvar *site* (site-with "pt-br" "es")
  "A site in English, Brazilian Portuguese and Spanish.")

(defun post (path &rest metadata)
  "Return a dated post at PATH with extra METADATA."
  (make-page :path path
             :body "<p>x</p>"
             :metadata (append (list :title path
                                     :layout :post
                                     :section "posts"
                                     :timestamp (parse-date "2026-01-01"))
                               metadata)))

(defun map-of (&rest pages)
  "Return a page map holding PAGES."
  (let ((page-map (make-page-map)))
    (dolist (page pages page-map)
      (add-page page-map page))))

(test the-default-language-comes-first-and-codes-are-lowercase
  (let ((site (make-site :title "T"
                         :language "pt-BR"
                         :languages '((:code "EN" :name "English")
                                      (:code "pt-br" :name "Portugues")))))
    (is (equal '("pt-BR" "en") (language-codes site)))
    (is (string= "Portugues" (getf (first (site-languages site)) :name)))))

(test a-site-without-languages-has-only-the-default
  (is (equal '("en") (language-codes (make-site :title "T")))))

(test paths-split-into-language-and-key
  (is (equal '("en" "/about/")
             (multiple-value-list (split-language-path *site* "/about/"))))
  (is (equal '("pt-br" "/about/")
             (multiple-value-list (split-language-path *site* "/pt-br/about/"))))
  (is (equal '("pt-br" "/")
             (multiple-value-list (split-language-path *site* "/pt-br/"))))
  (is (equal '("en" "/fr/about/")
             (multiple-value-list (split-language-path *site* "/fr/about/")))))

(test localizing-prefixes-every-language-but-the-default
  (is (string= "" (language-prefix *site* "en")))
  (is (string= "/es" (language-prefix *site* "es")))
  (is (string= "/about/" (localize-path *site* "en" "/about/")))
  (is (string= "/es/about/" (localize-path *site* "es" "/about/"))))

(test translations-link-pages-that-share-a-key
  (let* ((result (add-translations
                  (map-of (make-page :path "/about/" :body "x"
                                     :metadata '(:layout :page))
                          (make-page :path "/pt-br/about/" :body "x"
                                     :metadata '(:layout :page))
                          (make-page :path "/es/other/" :body "x"
                                     :metadata '(:layout :page)))
                  *site*))
         (english (page-metadata (find-page result "/about/")))
         (spanish (page-metadata (find-page result "/es/other/"))))
    (is (equal '(("pt-br" . "/pt-br/about/")) (getf english :translations)))
    (is (string= "en" (getf english :lang)))
    (is (null (getf spanish :translations)))
    (is (string= "es" (getf spanish :lang)))))

(test an-explicit-lang-in-the-front-matter-wins
  (let ((result (add-translations
                 (map-of (make-page :path "/pt-br/a/" :body "x"
                                    :metadata '(:layout :page :lang "pt-PT")))
                 *site*)))
    (is (string= "pt-PT"
                 (getf (page-metadata (find-page result "/pt-br/a/")) :lang)))))

(test pages-without-a-layout-are-not-touched
  (let ((result (add-translations
                 (map-of (make-page :path "/style.css" :body "x"))
                 *site*)))
    (is (null (page-metadata (find-page result "/style.css"))))))

(test each-language-gets-its-own-section-index
  (let ((result (add-section-indexes
                 (map-of (post "/posts/a/") (post "/pt-br/posts/b/"))
                 *site*)))
    (is-true (find-page result "/posts/"))
    (is-true (find-page result "/pt-br/posts/"))
    (is (null (find-page result "/es/posts/")))))

(test each-language-gets-its-own-tags
  (let ((result (add-tag-pages
                 (map-of (post "/posts/a/" :tags '("Lisp"))
                         (post "/pt-br/posts/b/" :tags '("Macros")))
                 *site*)))
    (is-true (find-page result "/tags/lisp/"))
    (is (null (find-page result "/tags/macros/")))
    (is-true (find-page result "/pt-br/tags/macros/"))
    (is-true (find-page result "/pt-br/tags/"))))

(test each-language-gets-its-own-feeds
  (let* ((page-map (map-of (post "/posts/a/") (post "/pt-br/posts/b/")))
         (rss (add-feed page-map *site*))
         (atom (add-atom-feed page-map *site*)))
    (is-true (find-page rss "/feed.xml"))
    (is-true (find-page rss "/pt-br/feed.xml"))
    (is (null (find-page rss "/es/feed.xml")))
    (is-true (find-page atom "/pt-br/atom.xml"))))

(test page-language-reads-the-path
  (is (string= "es" (page-language *site* (make-page :path "/es/x/" :body "")))))

(test content-in-a-language-directory-keeps-its-section-and-layout
  (with-temp-directory (root)
    (write-text-file root "content/posts/a.md" "A")
    (write-text-file root "content/pt-br/posts/a.md" "A em portugues")
    (write-text-file root "content/pt-br/index.md" "Inicio")
    (let* ((site (make-site :title "T"
                            :root root
                            :languages '((:code "en" :name "English")
                                         (:code "pt-br" :name "Portugues"))))
           (pages (read-content site))
           (translated (page-metadata (find-page pages "/pt-br/posts/a/"))))
      (is (eq :post (getf translated :layout)))
      (is (string= "posts" (getf translated :section)))
      (is (eq :page (getf (page-metadata (find-page pages "/pt-br/")) :layout)))
      (is (string= "Home" (getf (page-metadata (find-page pages "/pt-br/"))
                                :title))))))

(test the-source-name-is-relative-to-the-content-directory
  (with-temp-directory (root)
    (write-text-file root "content/posts/a.md" "A")
    (let* ((site (make-site :title "T" :root root))
           (page (find-page (read-content site) "/posts/a/")))
      (is (string= "posts/a.md" (page-source-name site page)))
      (is (null (page-source-name site (make-page :path "/x/" :body "")))))))
