---
(:title "Command line"
 :description "quire build, quire serve and their options.")
---

```
quire build [--site FILE] [--out DIR] [--clean] [--drafts]
quire serve [--site FILE] [--port N] [--host ADDR] [--drafts]
quire version | help
```

| Option | Meaning |
|--------|---------|
| `--site FILE` | The site definition file |
| `--out DIR` | Where `build` writes the site |
| `--clean` | Empty the output directory first |
| `--drafts` | Include pages marked `:draft t` |
| `--port N`, `--host ADDR` | Where `serve` listens |

`--clean` empties the output directory first, but only when it is new, empty
or marked by a `.quire-output` file written by a previous build. quire never
deletes a directory it did not create.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | ok |
| `1` | quire error |
| `2` | usage error |
| `70` | internal error |
| `130` | interrupted |

## Deterministic builds

Building the same site twice produces identical bytes, so you can compare two
builds with `diff -r`. This site is built that way.

Next: [limits](../limits/).
