(defpackage #:quire/tests/outline
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/outline
                #:add-heading-anchors
                #:add-reading-time
                #:anchor-headings
                #:html->text
                #:reading-minutes)
  (:import-from #:quire/page
                #:make-page
                #:page-body
                #:page-metadata)
  (:import-from #:quire/page-map
                #:add-page
                #:find-page
                #:make-page-map)
  (:import-from #:quire/site
                #:make-site)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/outline)

(def-suite outline-suite
  :description "Heading anchors, tables of contents and reading time."
  :in quire-suite)

(in-suite outline-suite)

(defvar *site* (make-site :title "Test")
  "A site for steps that ignore it.")

(defun contains-p (needle haystack)
  "Return true when HAYSTACK contains NEEDLE."
  (and (search needle haystack) t))

(defun words (count)
  "Return a paragraph of COUNT words."
  (format nil "<p>~{~A~^ ~}</p>" (loop repeat count collect "word")))

(test headings-get-ids-from-their-text
  (is (string= "<h2 id=\"a-b\">A &amp; B</h2>"
               (anchor-headings "<h2>A &amp; B</h2>"))))

(test repeated-headings-get-numbered-ids
  (let ((html (anchor-headings "<h2>Same</h2><h3>Same</h3><h2>Same</h2>")))
    (is-true (contains-p "<h2 id=\"same\">" html))
    (is-true (contains-p "<h3 id=\"same-2\">" html))
    (is-true (contains-p "<h2 id=\"same-3\">" html))))

(test an-id-written-in-the-heading-is-kept
  (is (string= "<h2 id=\"mine\">Text</h2>"
               (anchor-headings "<h2 id=\"mine\">Text</h2>"))))

(test only-h2-and-h3-are-anchored
  (let ((html (anchor-headings "<h1>One</h1><h4>Four</h4>")))
    (is (string= "<h1>One</h1><h4>Four</h4>" html))))

(test the-outline-lists-level-id-and-text-in-order
  (is (equal '((2 "alpha" "Alpha") (3 "beta" "Beta"))
             (nth-value 1 (anchor-headings "<h2>Alpha</h2><p>x</p><h3>Beta</h3>")))))

(test headings-with-inline-markup-use-their-plain-text
  (is (equal '((2 "the-code" "The code"))
             (nth-value 1 (anchor-headings "<h2>The <code>code</code></h2>")))))

(test a-heading-without-letters-gets-a-fallback-id
  (is-true (contains-p "id=\"section\"" (anchor-headings "<h2>***</h2>"))))

(test text-conversion-drops-tags-and-decodes-entities
  (is (string= "a < b & c" (html->text "<p>a &lt; b &amp; <b>c</b></p>"))))

(test the-step-anchors-laid-out-pages-and-records-the-toc
  (let ((page-map (make-page-map)))
    (add-page page-map (make-page :path "/a/"
                                  :body "<h2>Intro</h2>"
                                  :metadata '(:layout :page)))
    (add-page page-map (make-page :path "/raw.txt" :body "<h2>Raw</h2>"))
    (let ((result (add-heading-anchors page-map *site*)))
      (is (string= "<h2 id=\"intro\">Intro</h2>"
                   (page-body (find-page result "/a/"))))
      (is (equal '((2 "intro" "Intro"))
                 (getf (page-metadata (find-page result "/a/")) :toc)))
      (is (string= "<h2>Raw</h2>" (page-body (find-page result "/raw.txt")))))))

(test reading-time-rounds-up-and-is-at-least-one-minute
  (is (= 1 (reading-minutes "<p>short</p>")))
  (is (= 1 (reading-minutes (words 200))))
  (is (= 2 (reading-minutes (words 201))))
  (is (= 1 (reading-minutes ""))))

(test code-blocks-do-not-count-as-reading
  (is (= 1 (reading-minutes
            (concatenate 'string
                         "<p>short</p><pre>"
                         (format nil "~{~A ~}" (loop repeat 1000 collect "x"))
                         "</pre>")))))

(test the-reading-time-step-sets-the-minutes
  (let ((page-map (make-page-map)))
    (add-page page-map (make-page :path "/a/"
                                  :body (words 450)
                                  :metadata '(:layout :post)))
    (is (= 3 (getf (page-metadata
                    (find-page (add-reading-time page-map *site*) "/a/"))
                   :reading-minutes)))))
