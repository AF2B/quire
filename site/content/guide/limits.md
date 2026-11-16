---
(:title "Limits"
 :description "What quire does not do yet.")
---

quire is at `0.1.0`, a public preview. The API may change before 1.0.

- SBCL only; interrupt handling and `save-lisp-and-die` are SBCL-specific.
- Raw HTML in Markdown passes through unchanged. Do not render content you do
  not trust.
- The Markdown parser (3bmd) is not strict CommonMark. Fenced code needs
  backticks, not tildes.
- Files whose name has no extension (such as `CNAME`) cannot be a site path
  and are skipped with a warning; dot-files are ignored.
- The watcher polls; it does not use inotify. Very large content trees make
  each poll slower.
- No incremental builds, i18n, image pipeline or plugin system yet.
- The feed is RSS only.

Found a problem? Open an issue on
[GitHub](https://github.com/AF2B/quire/issues).
