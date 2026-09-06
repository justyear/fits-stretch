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

## Regra permanente: nenhum identificador de cliente entra em texto

A regra acima cobre pixel. Esta cobre texto, e vale para **todo arquivo do
projeto** — código, comentário, documentação, nome de arquivo, e **mensagem de
commit**, que é a mais fácil de esquecer porque não aparece em nenhuma varredura
da árvore de trabalho.

Não entram:

- **nome de pessoa ou de empresa** — cliente, parceiro, quem mandou o arquivo
- **serial ou identificador de equipamento** — `TELESCOP` com número de série,
  id de sensor, id de montagem
- **alvo observado** quando ele identifica de quem é o dado — o objeto, a data
  de observação, o nome do arquivo original

**Medição fica.** Mediana, MADN, contraste de treliça, tempo de pipeline,
contagem de tiles: tudo isso é registro de engenharia e é o que faz a próxima
sessão não repetir trabalho. Vai atribuído a **"um parceiro de teste"**, sem
mais.

Certo:

> Um stack S30 Pro de um parceiro de teste tem MADN de 0,00007 no verde contra
> mediana 0,02025, então o autostretch sai com midtones 0,00059.

Errado, e é o mesmo parágrafo — com os identificadores aqui substituídos por
marcadores, porque escrever os verdadeiros num exemplo de "não faça isto" seria
fazer exatamente isto:

> O stack do &lt;NOME&gt; (&lt;OBJETO&gt;, `TELESCOP = S30 Pro_<serial>`,
> `r_<alvo>_All_<n>_E_stacked.fit`) tem MADN de 0,00007 no verde.

O modelo do equipamento pode ficar — "Seestar S30 Pro" descreve uma classe de
arquivo e é o que torna a medição reutilizável. O **serial** não: ele aponta
para um aparelho, e um aparelho aponta para uma pessoa.

Isto não se desfaz depois. Texto commitado fica no histórico do git mesmo depois
de editado, e mensagem de commit não se edita sem reescrever histórico.

## Regra operacional: o que um comando da sessão pode imprimir

As duas regras acima protegem a árvore. Esta protege o que fica **fora** dela.

A transcrição da sessão grava a saída de todo comando executado, e vive fora do
projeto — nenhum `.gitignore`, nenhuma varredura desta árvore e nenhuma revisão
de commit a alcança. Então a regra tem que valer no momento em que o comando
roda, não depois.

**Nenhum comando executado numa sessão deste projeto imprime, de arquivo de
terceiro:**

- `OBJECT`, `DATE-OBS`, `TELESCOP`, `INSTRUME`
- o caminho ou o nome do arquivo
- README, e-mail ou nota que tenha vindo junto

Precisa distinguir sintético de real num inventário? **O critério é a ausência
de `DATE-OBS` e `TELESCOP`** — fixture gerado por `make-fixture.ps1` não tem
nenhum dos dois. Reporte a conclusão, nunca o valor:

```
    4.150.080 B  test/fixtures/fixture-seestar.fit    sintetico
   99.544.320 B  <fora da arvore>                     REAL - nao imprimir campos
```

Isto não é higiene teórica. Uma auditoria encontrou **225 ocorrências do nome de
um cliente e 86 do serial do equipamento dele** numa transcrição, e a origem foi
um único inventário que imprimiu esses campos de cada arquivo. Apagar a
transcrição depois é conserto; esta regra é a prevenção, e é a única que impede
a repetição.

## Retenção da transcrição: 1 dia

`"cleanupPeriodDays": 1` em `~/.claude/settings.json`. É o mínimo aceito — `0` é
rejeitado na validação, e não existe interruptor para desligar a escrita.

**Consequência, e ela é operacional:** decisão técnica que só existe na conversa
**se perde em 24 horas**. Toda decisão que precisa sobreviver à sessão vai para
`NOTAS-SESSAO-FITS.md` ou para a spec do módulo **antes do fim da sessão** — não
no dia seguinte, não "quando der".

Isso quase custou a decisão da identidade do git deste repositório, que existia
só na conversa e só foi para o `NOTAS` porque uma auditoria a procurou de
propósito antes de apagar a transcrição. Da próxima vez não haverá auditoria.

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
