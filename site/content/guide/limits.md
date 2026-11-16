---
(:title "Limits"
 :description "What quire does not do yet.")
---

quire is at `0.1.0`, a public preview. The API may change before 1.0.

- SBCL is the reference implementation. The suite also passes on ECL 21.2 and
  Clozure CL 1.13, but those runs are experimental, and the standalone
  executable and Ctrl-C handling are SBCL-only.
- Raw HTML in Markdown passes through unchanged. Do not render content you do
  not trust.
- The Markdown parser (3bmd) is not strict CommonMark. Fenced code needs
  backticks, not tildes.
- Files whose name has no extension cannot be a site path and are skipped with
  a warning, except `CNAME` and `LICENSE`. Hidden files are ignored, except
  `.nojekyll` and `.well-known/`.
- The watcher polls; it does not use inotify. Very large content trees make
  each poll slower.
- Every build reads and renders the whole site; the dev server reuses the
  rendered Markdown of unchanged files, but a one-shot build does not.
- No image pipeline yet.
- Translations are matched by path. There is no way to link two pages whose
  paths differ, and the theme's interface strings cover five languages only.
- A series cannot be announced before its first part is published.
- Footnotes are one line each, and containers do not nest.
- Extensions are build steps; there is no separate plugin system.

Found a problem? Open an issue on
[GitHub](https://github.com/AF2B/quire/issues).
