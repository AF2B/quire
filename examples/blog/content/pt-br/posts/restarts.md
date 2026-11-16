---
(:title "Restarts: a metade do tratamento de erros que ninguém ensina"
 :date "2026-11-09"
 :tags ("common-lisp" "condicoes")
 :series "O sistema de condições, de ponta a ponta"
 :part 2
 :series-total 4
 :featured t
 :kicker "Sistema de condições"
 :description "A maioria das linguagens dá uma ferramenta para falhas: desempilhar até alguém capturar. Common Lisp separa quem sabe se recuperar de quem sabe qual recuperação escolher.")
---

## Duas metades de uma falha

Texto de exemplo. Substitua pelo seu.

## Um restart que você pode invocar

```lisp
(restart-case (error "boom")
  (use-value (v) v))
```
