---
(:title "Deterministic builds"
 :date "2026-11-14"
 :tags ("design")
 :description "Same content in, same bytes out.")
---

Pages are written in path order, dates come from the content and never from the
clock, and the feed's build date is the date of its newest item. Build twice and
compare:

| Check | Result |
|-------|--------|
| Same files | yes |
| Same bytes | yes |
| Depends on the clock | no |

A deterministic build makes a diff of the output a diff of the content.
