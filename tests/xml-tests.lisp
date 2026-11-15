(defpackage #:quire/tests/xml
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/xml
                #:xml-escape))

(in-package #:quire/tests/xml)

(def-suite xml-suite
  :description "XML escaping."
  :in quire-suite)

(in-suite xml-suite)

(test the-five-predefined-entities-are-escaped
  (is (string= "&amp;&lt;&gt;&quot;&apos;" (xml-escape "&<>\"'"))))

(test plain-text-is-unchanged
  (is (string= "Olá, mundo" (xml-escape "Olá, mundo"))))

(test characters-xml-cannot-carry-are-dropped
  (is (string= "ab" (xml-escape (format nil "a~Cb" (code-char 1)))))
  (is (string= (format nil "a~Cb" #\Tab) (xml-escape (format nil "a~Cb" #\Tab)))))

(test non-string-is-a-type-error
  (signals type-error (xml-escape nil)))
