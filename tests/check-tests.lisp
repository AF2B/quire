(defpackage #:quire/tests/check
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/check
                #:broken-link-href
                #:broken-link-page
                #:broken-link-reason
                #:check-links)
  (:import-from #:quire/page
                #:make-page)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/check)

(def-suite check-suite
  :description "Verification of the internal links of a built site."
  :in quire-suite)

(in-suite check-suite)

(defun page-map-of (&rest paths-and-bodies)
  "Return a page map from alternating paths and bodies in PATHS-AND-BODIES."
  (let ((page-map (make-page-map)))
    (loop for (path body) on paths-and-bodies by #'cddr
          do (add-page page-map (make-page :path path :body body)))
    page-map))

(defun broken-in (page-map &key (base-url ""))
  "Return (PAGE HREF REASON) lists for the broken links of PAGE-MAP."
  (mapcar (lambda (broken)
            (list (broken-link-page broken)
                  (broken-link-href broken)
                  (broken-link-reason broken)))
          (check-links page-map (make-site :title "T" :base-url base-url))))

(test a-site-whose-links-all-work-has-no-broken-links
  (is (null (broken-in (page-map-of
                        "/" "<a href=\"/about/\">About</a>"
                        "/about/" "<a href=/>Home</a>"
                        "/css/site.css" "body {}")))))

(test links-to-missing-pages-are-reported-with-their-source
  (is (equal '(("/" "/nope/" :missing-page))
             (broken-in (page-map-of "/" "<a href=\"/nope/\">x</a>")))))

(test relative-links-resolve-from-the-directory-of-the-page
  (is (null (broken-in (page-map-of
                        "/guide/a/" "<a href=\"../b/\">b</a> <a href=\"c.html\">c</a>"
                        "/guide/b/" "x"
                        "/guide/a/c.html" "<p>c</p>"))))
  (is (equal '(("/guide/a/" "../zzz/" :missing-page))
             (broken-in (page-map-of
                         "/guide/a/" "<a href=\"../zzz/\">z</a>")))))

(test links-above-the-root-are-broken
  (is (equal '(("/a/" "../../x/" :missing-page))
             (broken-in (page-map-of "/a/" "<a href=\"../../x/\">x</a>")))))

(test a-directory-link-without-a-trailing-slash-is-accepted
  (is (null (broken-in (page-map-of
                        "/" "<a href=\"/about\">About</a>"
                        "/about/" "x")))))

(test absolute-links-must-include-the-base-path
  (let ((page-map (page-map-of
                   "/" "<a href=\"/blog/about/\">ok</a> <a href=\"/about/\">bad</a>"
                   "/about/" "x")))
    (is (equal '(("/" "/about/" :outside-base-path))
               (broken-in page-map :base-url "https://example.com/blog")))))

(test external-fragment-and-scheme-links-are-not-followed
  (is (null (broken-in
             (page-map-of
              "/" (format nil "<a href=\"https://example.com/x\">a</a>~
                               <a href=\"mailto:me@example.com\">b</a>~
                               <a href=\"#top\">c</a>~
                               <a href=\"//cdn.example.com/x.js\">d</a>"))))))

(test queries-and-fragments-are-stripped-before-resolving
  (is (null (broken-in (page-map-of
                        "/" "<a href=\"/about/?a=1#team\">About</a>"
                        "/about/" "x")))))

(test src-attributes-are-checked-too
  (is (equal '(("/" "/img/missing.png" :missing-page))
             (broken-in (page-map-of
                         "/" "<img src=/img/missing.png alt=\"\">")))))

(test words-that-look-like-attributes-are-not-links
  (is (null (broken-in (page-map-of
                        "/" "<div data-href=\"/nope/\">use href=/nope/ here</div>")))))

(test only-html-pages-are-scanned
  (is (null (broken-in (page-map-of
                        "/feed.xml" "<link href=\"/nope/\"/>"
                        "/css/a.css" "a { background: url(\"/nope.png\") }")))))

(test function-bodies-are-resolved-before-scanning
  (let ((page-map (make-page-map)))
    (add-page page-map
              (make-page :path "/"
                         :body (lambda (page)
                                 (declare (ignore page))
                                 "<a href=\"/nope/\">x</a>")))
    (is (equal '(("/" "/nope/" :missing-page))
               (broken-in page-map)))))

(test results-follow-page-order-then-document-order
  (is (equal '(("/a/" "/1/" :missing-page)
               ("/a/" "/2/" :missing-page)
               ("/b/" "/3/" :missing-page))
             (broken-in (page-map-of
                         "/b/" "<a href=\"/3/\">3</a>"
                         "/a/" "<a href=\"/1/\">1</a><a href=\"/2/\">2</a>")))))
