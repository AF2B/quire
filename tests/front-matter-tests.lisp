(defpackage #:quire/tests/front-matter
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:front-matter-error
                #:front-matter-error-reason)
  (:import-from #:quire/front-matter
                #:split-front-matter)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/front-matter)

(def-suite front-matter-suite
  :description "Splitting a content file into metadata and body."
  :in quire-suite)

(in-suite front-matter-suite)

(defun lines (&rest strings)
  "Return STRINGS joined by LF."
  (format nil "~{~A~^~%~}" strings))

(defun reason-of (text)
  "Return the reason SPLIT-FRONT-MATTER rejects TEXT, or NIL when it accepts."
  (handler-case (progn (split-front-matter text) nil)
    (front-matter-error (condition) (front-matter-error-reason condition))))

(test text-without-fence-has-no-metadata
  (multiple-value-bind (metadata body) (split-front-matter (lines "# Hi" "" "x"))
    (is-false metadata)
    (is (string= (lines "# Hi" "" "x") body))))

(test fenced-block-is-read-as-a-plist
  (multiple-value-bind (metadata body)
      (split-front-matter (lines "---"
                                 "(:title \"Hi\" :tags (\"a\" \"b\") :n 3)"
                                 "---"
                                 "Body"
                                 ""))
    (is (equal '(:title "Hi" :tags ("a" "b") :n 3) metadata))
    (is (string= (lines "Body" "") body))))

(test multi-line-plist-is-accepted
  (is (equal '(:title "Hi" :draft t)
             (split-front-matter (lines "---"
                                        "(:title \"Hi\""
                                        " :draft t)"
                                        "---"
                                        "x")))))

(test boolean-symbols-keep-their-meaning
  (is (eq t (getf (split-front-matter (lines "---" "(:draft t)" "---" "x"))
                  :draft)))
  (is-false (getf (split-front-matter (lines "---" "(:draft nil)" "---" "x"))
                  :draft)))

(test empty-block-means-no-metadata
  (multiple-value-bind (metadata body)
      (split-front-matter (lines "---" "---" "Body"))
    (is-false metadata)
    (is (string= "Body" body))))

(test crlf-line-endings-are-normalized
  (multiple-value-bind (metadata body)
      (split-front-matter (format nil "---~C~C(:title \"Hi\")~C~C---~C~CBody~C~C"
                                  #\Return #\Newline #\Return #\Newline
                                  #\Return #\Newline #\Return #\Newline))
    (is (equal '(:title "Hi") metadata))
    (is (string= (format nil "Body~%") body))))

(test byte-order-mark-is-ignored
  (is (equal '(:title "Hi")
             (split-front-matter
              (format nil "~C---~%(:title \"Hi\")~%---~%x" (code-char #xFEFF))))))

(test rule-inside-the-body-is-not-a-fence
  (multiple-value-bind (metadata body)
      (split-front-matter (lines "---" "(:title \"Hi\")" "---" "a" "---" "b"))
    (is (equal '(:title "Hi") metadata))
    (is (string= (lines "a" "---" "b") body))))

(test missing-closing-fence-is-rejected
  (is (eq :unterminated (reason-of (lines "---" "(:title \"Hi\")" "Body")))))

(test unreadable-metadata-is-rejected
  (is (eq :unreadable (reason-of (lines "---" "(:title" "---" "x")))))

(test reader-evaluation-is-disabled
  (is (eq :unreadable
          (reason-of (lines "---" "(:title #.(+ 1 2))" "---" "x")))))

(test more-than-one-form-is-rejected
  (is (eq :trailing-forms
          (reason-of (lines "---" "(:a 1) (:b 2)" "---" "x")))))

(test metadata-must-be-a-keyword-plist
  (is (eq :not-a-plist (reason-of (lines "---" "(1 2)" "---" "x"))))
  (is (eq :not-a-plist (reason-of (lines "---" "(:a)" "---" "x"))))
  (is (eq :not-a-plist (reason-of (lines "---" "\"text\"" "---" "x")))))

(test non-string-text-is-a-type-error
  (signals type-error (split-front-matter nil)))
