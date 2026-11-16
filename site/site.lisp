(in-package #:quire-user)

;;; The product site of quire, built with quire. Build it with:
;;;   quire build --site site/site.lisp --out public
;;; or serve it with live reload:
;;;   quire serve --site site/site.lisp

(setf *site*
      (make-site :title "quire"
                 :description "Pages are functions. Sites are data."
                 :base-url "https://af2b.github.io/quire"
                 :author "André Borba"
                 :layouts (quire/theme-borba:layouts)
                 :steps (quire/theme-borba:steps)
                 :extra '(:nav (("Home" . "/")
                                ("Guide" . "/guide/")))))
