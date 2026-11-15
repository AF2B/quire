(in-package #:quire-user)

;;; The demo site. Build it with:
;;;   quire build --site examples/demo/site.lisp
;;; or serve it with live reload:
;;;   quire serve --site examples/demo/site.lisp

(setf *site*
      (make-site :title "quire"
                 :description "Pages are functions. Sites are data."
                 :base-url "https://quire.example"
                 :author "Quire Demo"
                 :layouts (quire/theme-borba:layouts)
                 :steps (quire/theme-borba:steps)
                 :extra '(:nav (("Home" . "/")
                                ("Posts" . "/posts/")
                                ("Tags" . "/tags/")
                                ("About" . "/about/")))))
