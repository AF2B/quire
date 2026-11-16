---
(:title "Note: sort is destructive, and ECL will tell you"
 :date "2026-10-19"
 :tags ("note" "portability")
 :description "A bug that only another implementation could show.")
---

Use the result of `sort`, never the argument. SBCL happened to keep the list
intact; ECL did not.
