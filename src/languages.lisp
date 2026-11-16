(defpackage #:quire/languages
  (:use #:cl)
  (:import-from #:quire/page
                #:copy-page
                #:page-metadata
                #:page-path)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map
                #:page-map-pages)
  (:import-from #:quire/paths
                #:+path-separator+)
  (:import-from #:quire/site
                #:site-language
                #:site-languages)
  (:export #:add-translations
           #:language-codes
           #:language-prefix
           #:localize-path
           #:page-language
           #:page-translation-key
           #:split-language-path))

(in-package #:quire/languages)

(defun language-codes (site)
  "Return the language codes of SITE, the default language first.

SITE: the site being built."
  (mapcar (lambda (entry) (getf entry :code))
          (site-languages site)))

(defun split-language-path (site path)
  "Return the language code and the language-free key of PATH.

A path that starts with the code of a language other than the default, as in
\"/pt-br/about/\", yields \"pt-br\" and \"/about/\". Any other path belongs to the
default language and is its own key.

SITE: the site being built.
PATH: a valid URL path."
  (let* ((default (site-language site))
         (end (position +path-separator+ path :start 1))
         (first-segment (and end (subseq path 1 end))))
    (if (and first-segment
             (string/= first-segment default)
             (member first-segment (language-codes site) :test #'string=))
        (values first-segment (subseq path end))
        (values default path))))

(defun language-prefix (site code)
  "Return the path prefix of the language CODE: empty for the default language.

SITE: the site being built.
CODE: a language code of SITE."
  (if (string= code (site-language site))
      ""
      (concatenate 'string "/" code)))

(defun localize-path (site code key)
  "Return the URL path of the page KEY in the language CODE.

SITE: the site being built.
CODE: a language code of SITE.
KEY: a language-free path such as \"/about/\"."
  (concatenate 'string (language-prefix site code) key))

(defun page-language (site page)
  "Return the language code of PAGE, taken from its path.

SITE: the site being built.
PAGE: the page to inspect."
  (values (split-language-path site (page-path page))))

(defun page-translation-key (site page)
  "Return the path of PAGE without its language prefix.

SITE: the site being built.
PAGE: the page to inspect."
  (nth-value 1 (split-language-path site (page-path page))))

(defun translations-of (site page pages-by-key)
  "Return the pairs (CODE . PATH) of the other languages that have PAGE.

Pairs follow the order of the languages of SITE.

SITE: the site being built.
PAGE: the page whose translations to find.
PAGES-BY-KEY: hash table of translation key to the pages that share it."
  (multiple-value-bind (code key) (split-language-path site (page-path page))
    (loop for other in (gethash key pages-by-key)
          for other-code = (page-language site other)
          unless (string= other-code code)
            collect (cons other-code (page-path other)) into pairs
          finally (return (sort pairs
                                #'<
                                :key (lambda (pair)
                                       (position (car pair)
                                                 (language-codes site)
                                                 :test #'string=)))))))

(defun add-translations (page-map site)
  "Return PAGE-MAP with :LANG and :TRANSLATIONS set on every laid-out page.

:LANG is the language code of the page, unless the front matter set it.
:TRANSLATIONS lists (CODE . PATH) for the same page in the other languages, so a
layout can link them. Pages that share a path once the language prefix is
removed are translations of each other. Run this after the steps that generate
pages and before APPLY-LAYOUTS.

PAGE-MAP: the page map to transform.
SITE: the site being built."
  (let ((pages (page-map-pages page-map))
        (by-key (make-hash-table :test 'equal))
        (result (make-page-map)))
    (dolist (page pages)
      (when (getf (page-metadata page) :layout)
        (push page (gethash (page-translation-key site page) by-key))))
    (dolist (page pages result)
      (add-page result
                (if (getf (page-metadata page) :layout)
                    (let ((metadata (copy-list (page-metadata page))))
                      (unless (getf metadata :lang)
                        (setf (getf metadata :lang) (page-language site page)))
                      (setf (getf metadata :translations)
                            (translations-of site page by-key))
                      (copy-page page :metadata metadata))
                    page)))))
