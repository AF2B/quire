(defpackage #:quire/tests/server
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/page
                #:make-page)
  (:import-from #:quire/page-map
                #:add-page
                #:make-page-map)
  (:import-from #:quire/server
                #:+events-path+
                #:content-type-for
                #:refresh
                #:reload-browsers
                #:respond
                #:server-generation
                #:server-last-error
                #:server-port
                #:start-server
                #:stop-server)
  (:import-from #:quire/tests/suite
                #:quire-suite)
  (:import-from #:quire/tests/support
                #:with-temp-directory
                #:write-text-file))

(in-package #:quire/tests/server)

(def-suite server-suite
  :description "Development server: routing, live layouts, reload events."
  :in quire-suite)

(in-suite server-suite)

(defparameter *poll-seconds* 0.05
  "Pause between two checks while waiting for something to happen.")

(defparameter *wait-seconds* 8
  "How long a test waits for a server event before giving up.")

(defvar *greeting* "hello"
  "Text the live layout of the tests renders; tests rebind it.")

(defun live-layout (page site pages)
  "Return a small HTML page that shows *GREETING*."
  (declare (ignore page site pages))
  (format nil "<html><body><p>~A</p></body></html>" *greeting*))

(defun sample-builder ()
  "Return a page map with HTML, CSS, bytes and a broken layout page."
  (let ((page-map (make-page-map)))
    (add-page page-map (make-page :path "/"
                                  :body (lambda (page)
                                          (declare (ignore page))
                                          (live-layout nil nil nil))))
    (add-page page-map (make-page :path "/plain/"
                                  :body "<h1>no body tag</h1>"))
    (add-page page-map (make-page :path "/blog/x/" :body "<body>x</body>"))
    (add-page page-map (make-page :path "/style.css" :body "a{}"))
    (add-page page-map (make-page :path "/img/a.png"
                                  :body (coerce #(1 2 3)
                                                '(vector (unsigned-byte 8)))))
    (add-page page-map (make-page :path "/boom/"
                                  :body (lambda (page)
                                          (declare (ignore page))
                                          (error "layout <exploded>"))))
    page-map))

(defmacro with-server ((variable builder &rest options) &body body)
  "Run BODY with VARIABLE bound to a started server on a free port.

The server is stopped afterwards.

VARIABLE: the symbol bound to the server.
BUILDER: a form that returns the builder function.
OPTIONS: extra keyword arguments for START-SERVER."
  `(let ((,variable (start-server ,builder :port 0 ,@options)))
     (unwind-protect (progn ,@body)
       (stop-server ,variable))))

(defun wait-until (predicate)
  "Return true as soon as PREDICATE does, or NIL after *WAIT-SECONDS*.

PREDICATE: a function of no arguments."
  (loop with deadline = (+ (get-internal-real-time)
                           (* *wait-seconds* internal-time-units-per-second))
        thereis (funcall predicate)
        while (< (get-internal-real-time) deadline)
        do (sleep *poll-seconds*)))

(defun http-get (port path)
  "Fetch PATH from the local server on PORT and return the raw response text."
  (usocket:with-client-socket (socket stream "127.0.0.1" port)
    (format stream "GET ~A HTTP/1.0~C~C~C~C" path #\Return #\Newline
            #\Return #\Newline)
    (finish-output stream)
    (with-output-to-string (out)
      (loop for line = (read-line stream nil)
            while line
            do (write-line line out)))))

(defun contains-p (needle haystack)
  "Return true when HAYSTACK contains NEEDLE."
  (and (search needle haystack) t))

(test content-types-follow-the-extension
  (is (string= "text/html; charset=utf-8" (content-type-for "/")))
  (is (string= "text/html; charset=utf-8" (content-type-for "/a/b/")))
  (is (string= "text/css; charset=utf-8" (content-type-for "/css/a.CSS")))
  (is (string= "image/png" (content-type-for "/a.png")))
  (is (string= "font/ttf" (content-type-for "/fonts/Inter.ttf")))
  (is (string= "application/octet-stream" (content-type-for "/a.unknown"))))

(test pages-are-served-with-the-live-reload-script
  (with-server (server #'sample-builder)
    (multiple-value-bind (status type body) (respond server "/")
      (is (= 200 status))
      (is (string= "text/html; charset=utf-8" type))
      (is-true (contains-p "<p>hello</p>" body))
      (is-true (contains-p (format nil "~A</body>" "</script>") body)
               "the script goes right before the closing body tag"))
    (is-true (contains-p "EventSource(\"/__quire/events\")"
                         (nth-value 2 (respond server "/plain/"))))))

(test non-html-responses-are-untouched
  (with-server (server #'sample-builder)
    (multiple-value-bind (status type body) (respond server "/style.css")
      (is (= 200 status))
      (is (string= "text/css; charset=utf-8" type))
      (is (string= "a{}" body)))
    (is (equalp #(1 2 3) (nth-value 2 (respond server "/img/a.png"))))))

(test missing-pages-are-404
  (with-server (server #'sample-builder)
    (is (= 404 (respond server "/nope/")))))

(test directory-without-slash-redirects
  (with-server (server #'sample-builder)
    (multiple-value-bind (status type body location) (respond server "/blog/x")
      (declare (ignore type body))
      (is (= 301 status))
      (is (string= "/blog/x/" location)))))

(test invalid-paths-are-400
  (with-server (server #'sample-builder)
    (is (= 400 (respond server "/a/../b/")))
    (is (= 400 (respond server "")))))

(test layout-failures-become-an-escaped-500-page
  (with-server (server #'sample-builder)
    (multiple-value-bind (status type body) (respond server "/boom/")
      (is (= 500 status))
      (is (string= "text/html; charset=utf-8" type))
      (is-true (contains-p "layout &lt;exploded&gt;" body)))))

(test redefined-layouts-show-on-the-next-request
  (with-server (server #'sample-builder)
    (is-true (contains-p "hello" (nth-value 2 (respond server "/"))))
    (let ((*greeting* "changed"))
      (is-true (contains-p "changed" (nth-value 2 (respond server "/")))))))

(test failed-builds-are-shown-instead-of-the-site
  (with-server (server (lambda () (error "no content directory")))
    (is-true (contains-p "no content directory" (server-last-error server)))
    (multiple-value-bind (status type body) (respond server "/")
      (declare (ignore type))
      (is (= 500 status))
      (is-true (contains-p "no content directory" body)))))

(test refresh-rebuilds-and-recovers-from-a-failure
  (let ((fail t))
    (with-server (server (lambda ()
                           (if fail
                               (error "broken")
                               (sample-builder))))
      (is-true (server-last-error server))
      (setf fail nil)
      (refresh server)
      (is-false (server-last-error server))
      (is (= 200 (respond server "/"))))))

(test refresh-and-reload-bump-the-generation
  (with-server (server #'sample-builder)
    (let ((before (server-generation server)))
      (reload-browsers server)
      (is (= (1+ before) (server-generation server)))
      (refresh server)
      (is (= (+ before 2) (server-generation server))))))

(test real-http-requests-are-answered
  (with-server (server #'sample-builder)
    (let ((response (http-get (server-port server) "/")))
      (is-true (contains-p "200 OK" response))
      (is-true (contains-p "<p>hello</p>" response))
      (is-true (contains-p "no-store" response)))
    (is-true (contains-p "404" (http-get (server-port server) "/nope/")))
    (is-true (contains-p "301" (http-get (server-port server) "/blog/x")))
    (is-true (contains-p "Location: /blog/x/"
                         (http-get (server-port server) "/blog/x")))))

(defun read-event-line (stream)
  "Return the next line of STREAM that starts with data:, or NIL on timeout."
  (loop with deadline = (+ (get-internal-real-time)
                           (* *wait-seconds* internal-time-units-per-second))
        while (< (get-internal-real-time) deadline)
        do (if (listen stream)
               (let ((line (string-trim '(#\Return) (read-line stream))))
                 (when (and (>= (length line) 5) (string= "data:" line :end2 5))
                   (return line)))
               (sleep *poll-seconds*))))

(test event-stream-announces-reloads
  (with-server (server #'sample-builder)
    (usocket:with-client-socket (socket stream "127.0.0.1" (server-port server))
      (format stream "GET ~A HTTP/1.0~C~C~C~C" +events-path+ #\Return #\Newline
              #\Return #\Newline)
      (finish-output stream)
      (loop for line = (read-line stream)
            until (string= "" (string-trim '(#\Return) line)))
      (reload-browsers server)
      (is (equal "data: reload" (read-event-line stream))))))

(test changing-a-watched-file-refreshes-the-site
  (with-temp-directory (directory)
    (write-text-file directory "page.txt" "one")
    (flet ((builder ()
             (let ((page-map (make-page-map))
                   (text (quire/files:read-file-text
                          (merge-pathnames "page.txt" directory))))
               (add-page page-map (make-page :path "/page.txt" :body text))
               page-map)))
      (with-server (server #'builder :watch (list directory))
        (is (string= "one" (nth-value 2 (respond server "/page.txt"))))
        (let ((before (server-generation server)))
          (write-text-file directory "page.txt" "second version")
          (is-true (wait-until (lambda ()
                                 (> (server-generation server) before))))
          (is (string= "second version"
                       (nth-value 2 (respond server "/page.txt")))))))))
