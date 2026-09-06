# Stretch — regras da árvore

## Regra permanente: nenhum dado astronômico de terceiro entra aqui

**Nenhum arquivo de imagem astronômica de terceiro entra nesta árvore, em
nenhuma circunstância.** Nem como fixture, nem "temporariamente", nem em
`.claude/shots/`, nem sob outro nome.

Vale para o dado e para tudo que deriva dele:

- o `.fit` / `.fits` / `.fz` / `.xisf` original
- um recorte, um stack, um starless, uma máscara, um export descomprimido
- **um PNG renderizado a partir dele** — render de dado de parceiro é dado de
  parceiro
- um golden (log, diag ou imagem) capturado a partir dele

Se um arquivo desses aparecer na árvore, ele sai. Não move para outra pasta do
projeto, não renomeia: sai.

## O que os testes usam no lugar

Fixtures sintéticos, gerados por `.claude/make-fixture.ps1` a partir de semente
fixa. São reprodutíveis byte a byte — regerar produz o mesmo arquivo — então
podem ser versionados sem que ninguém precise confiar neles.

```
powershell -File .claude\make-fixture.ps1
```

| fixture | cobre |
|---|---|
| `test/fixtures/fixture-seestar.fit` | int16 + BZERO, ROWORDER BOTTOM-UP, detecção CFA, debayer GRBG, ramo linear |
| `test/fixtures/fixture-rice.fit.fz` | RICE_1, SUBTRACTIVE_DITHER_2, sentinela de zero exato, 3 planos, `view.factor` 2 |
| `test/fixtures/fixture-nonlinear.fit` | float32 sem compressão, ROWORDER TOP-DOWN, ramo não-linear (mediana 0,25 + HISTORY) |

Precisa de um caminho novo coberto? **Estenda o gerador**, não arranje um
arquivo real.

## Se um teste realmente exigir dado real

Roda a partir de um caminho **fora do projeto**, e **nada é escrito de volta**
para dentro dele — nem a imagem, nem o log, nem o golden, nem uma captura em
`.claude/shots/`. O resultado dessa rodada é olhado e descartado. Se virar
regressão que precisa persistir, o caminho é reproduzir o fenômeno num fixture
sintético.

`.claude/serve.ps1` não mapeia nada fora da pasta do projeto. Manter assim.

## Reforço mecânico

`.gitignore` ignora `*.fit`, `*.fits`, `*.fz`, `*.fts` e `*.xisf` em qualquer
lugar da árvore, e libera **por nome** só os três fixtures sintéticos. Um
arquivo novo desses é invisível para o git até alguém escrever a exceção à mão —
que é exatamente o momento em que a pergunta "de quem é isso?" precisa ser feita.

## O resto do projeto

- `index.html` é **gerado**. Não editar à mão. Fonte em `src/pipeline/` +
  `build/template.html`, montado por `build/build.ps1`.
- Sem Node, sem esbuild, sem dependência de build. Ver `modulo-0-spec.md` §2.
- Verificação: `.claude/serve.ps1`, `test/capture-golden.js`,
  `test/compare-golden.ps1`. Comparação estrita — a única tolerância é
  `timingsMs`.
