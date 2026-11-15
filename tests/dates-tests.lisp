(defpackage #:quire/tests/dates
  (:use #:cl
        #:fiveam)
  (:import-from #:quire/conditions
                #:invalid-date)
  (:import-from #:quire/dates
                #:format-iso-date
                #:format-iso-datetime
                #:format-rfc-822
                #:parse-date)
  (:import-from #:quire/tests/suite
                #:quire-suite))

(in-package #:quire/tests/dates)

(def-suite dates-suite
  :description "ISO 8601 parsing and date formatting."
  :in quire-suite)

(in-suite dates-suite)

(test date-only-means-midnight-utc
  (is (= (encode-universal-time 0 0 0 14 11 2026 0)
         (parse-date "2026-11-14"))))

(test datetime-is-parsed-with-or-without-z
  (let ((expected (encode-universal-time 5 30 10 14 11 2026 0)))
    (is (= expected (parse-date "2026-11-14T10:30:05")))
    (is (= expected (parse-date "2026-11-14T10:30:05Z")))))

(test leap-day-is-valid-only-in-leap-years
  (is-true (parse-date "2024-02-29"))
  (is-true (parse-date "2000-02-29"))
  (signals invalid-date (parse-date "2025-02-29"))
  (signals invalid-date (parse-date "1900-02-29")))

(test malformed-dates-are-rejected
  (dolist (text '(""
                  "2026"
                  "2026-11"
                  "2026-1-14"
                  "2026/11/14"
                  "2026-13-01"
                  "2026-00-10"
                  "2026-11-31"
                  "2026-11-00"
                  "2026-11-14T24:00:00"
                  "2026-11-14T10:60:00"
                  "2026-11-14T10:00:60"
                  "2026-11-14 10:00:00"
                  "2026-11-14T10:00"
                  "2026-11-14T10:00:00+01:00"
                  "1899-12-31"
                  "+026-11-14"
                  "abcd-ef-gh"))
    (signals invalid-date (parse-date text))))

(test formats-round-trip
  (let ((universal-time (parse-date "2026-11-14T10:30:05Z")))
    (is (string= "2026-11-14" (format-iso-date universal-time)))
    (is (string= "2026-11-14T10:30:05Z" (format-iso-datetime universal-time)))))

(test rfc-822-names-the-right-weekday
  (is (string= "Sat, 14 Nov 2026 00:00:00 +0000"
               (format-rfc-822 (parse-date "2026-11-14"))))
  (is (string= "Sat, 01 Jan 2000 12:00:00 +0000"
               (format-rfc-822 (parse-date "2000-01-01T12:00:00Z"))))
  (is (string= "Thu, 29 Feb 2024 23:59:59 +0000"
               (format-rfc-822 (parse-date "2024-02-29T23:59:59Z")))))
