# Notas de sessão — ferramenta FITS (Stretch)

Handoff para quem pegar isto depois, inclusive eu mesmo sem contexto.

## O que é

`stretch-tool/index.html` — **82.267 bytes**, arquivo único, HTML/CSS/JS puro,
sem dependência externa, sem build, sem backend. Abre FITS empilhado, detecta e
aplica debayer, aplica autostretch MTF, e emite um **log de processamento** que
o usuário cola em público como prova de que a imagem foi processada e não
gerada. O log é o produto; a imagem é o subproduto.

Botões: baixar PNG, copiar log, e — só quando a entrada chegou comprimida —
baixar FITS descomprimido.

Diagnóstico escondido: tecla **D** ou `#debug`. Mostra header cru, todas as
decisões com o número que as motivou, e tempos por estágio. Expõe também
`window.__loadFromURL(url)`, que é como a verificação automatizada carrega
arquivos sem depender de arrastar à mão.

## Estado de verificação

### Verificado contra dado real

Os arquivos reais desta tabela **não estão mais na árvore** (CLAUDE.md). A
verificação aconteceu e vale como registro; o que é re-executável hoje está na
tabela seguinte.

| Caso (histórico, arquivo removido) | O que provou |
|---|---|
| Stack `.fz` de parceiro (Rice, 2160×3840×3, Siril 1.4.4) | Descompressão Rice: **12/12** valores batem com astropy em 6 casas |
| Subs de parceiro (Seestar S30 Pro, 16-bit, BAYERPAT GRBG) | Caminho CFA/debayer em dado real — **encontrou um bug**, ver abaixo |
| `r_M45_stacked.fit` (313 MB, float32, iTelescope/Siril) | Detecção de não-linearidade; 3 planos pulam debayer; arquivo grande não trava |
| Round-trip do export FITS | 24.883.200 pixels **bit-idênticos**, ordem de linha preservada |

### Re-executável hoje (fixtures sintéticos + goldens)

| Caso | O que cobre |
|---|---|
| `fixture-seestar.fit` | BZERO 32768, ROWORDER BOTTOM-UP, debayer GRBG com estrelas de cor conhecida, ramo linear |
| `fixture-rice.fit.fz` | RICE_1 BYTEPIX 4, SUBTRACTIVE_DITHER_2, sentinela de zero exato, 3 planos, `view.factor` 2 |
| `fixture-nonlinear.fit` | float32 sem compressão, ROWORDER TOP-DOWN, ramo não-linear (mediana 0,25 + HISTORY) |
| Texto renomeado para `.fit` | Erro amigável, sem stack trace |
| Caminho sem Web Worker | Log **byte a byte idêntico** ao do worker |

### NÃO verificado

- **`.fz` que ainda seja mosaico CFA**, de ponta a ponta. As duas metades estão
  verificadas em separado (descompressão com stack RGB; preservação de
  `BAYERPAT` e caminho 16-bit com os cards de um sub real), mas a combinação
  nunca passou por um arquivo real. Não existia um para testar.
- **Abrir por `file://` num navegador.** O navegador embutido não navega para
  arquivos fora da pasta do projeto e a extensão do Chrome não estava conectada.
  O que foi testado é o caminho de código que o `file://` aciona — o fallback
  sem worker, que blob workers bloqueados obrigam. O resto é carregamento
  estático sem requisição externa.
- **BYTEPIX 1 e 2 no Rice.** Implementados de forma genérica, exercidos zero
  vezes. Só BYTEPIX 4 (float) passou por dado real.
- **BITPIX -64.** Caminho existe, nunca rodou.
- **O `.fit` exportado aberto no Siril.** Foi validado relendo com o próprio
  parser e inspecionando o header no disco, fora do navegador. Nenhum Siril
  abriu o arquivo ainda.

## Decisões não óbvias

### Parser FITS próprio, sem biblioteca
`fitsjs` está parada desde ~2014; JS9 é o DS9 inteiro em WASM. Nada disso cabe
em arquivo único, e a legibilidade do arquivo inteiro é o que sustenta o
argumento de proveniência da ferramenta. O subconjunto necessário é pequeno.

### O MTF diverge do Siril de propósito
O código clássico do PixInsight/Siril calcula `midtones = MTF(mediana − c0, T)`
com a diferença **não** normalizada. Aqui é `MTF((mediana − c0)/(1 − c0), T)`,
que é a solução exata de `MTF(x, m) = T`. Diferença desprezível em dado linear
(c0 minúsculo), relevante no ramo não-linear (c0 grande). Garante que a mediana
cai exatamente no alvo. Divergência consciente, não descuido.

### Ramo não-linear: ponto preto por percentil, alvo na própria mediana
Detecção: `nonLinear = mediana ≥ 0.05 OU (HISTORY com marca de esticamento E
mediana ≥ 0.02)`. O HISTORY **abaixa o limiar**, não manda sozinho.

Quando dispara: ponto preto no percentil 0,05% em vez de corte em sigma, e
`target = a própria mediana do canal`. Motivo: em imagem já esticada o MADN é
pequeno perto da mediana, então `mediana − 2.8·MADN` cortaria 80% do brilho.
Com alvo na mediana o midtones sai perto de 0,5 e a transformação vira quase
identidade — só apara o preto e preserva a colocação tonal que já existia.

**O limiar não deve ser calibrado para fazer um arquivo de teste passar.** Se o
M45 reprovar, o erro está no código. Um limiar ajustado para agradar um arquivo
destrói exatamente o que o log deveria provar.

#### A identidade que os 8 bits escondiam — evidência de correção, não de mudança

Neste ramo `target` é a própria mediana do canal, e o midtones é escolhido como
`MTF(x, target)` com `x = (mediana − shadows) / (1 − shadows)`. Isso torna
`MTF(x, midtones) = target = mediana` **por construção**: a transformação leva a
mediana nela mesma. Logo `after.median` tem de ser igual a `before.median`.

Enquanto a cadeia entregava 8 bits, isso era invisível. A mediana de saída
pousava em `67/255 = 0,262745` — o nível quantizado mais próximo — e não havia
como distinguir "a identidade vale" de "caiu perto por acaso".

Com a cadeia em float pleno (Módulo 1, passo 2) a identidade aparece:

| canal | `before.median` | `after.median` | diferença |
|---|---|---|---|
| R | 0,2640573739223316 | 0,2640573739223316 | 0 |
| G | 0,24568551155870907 | 0,24571602960250247 | 3,05e-5 |
| B | 0,23041123064011595 | 0,23041123064011595 | 0 |

R e B batem **dígito a dígito**. O G não bate por 3,05e-5, que é dois bins do
histograma de 65536 — a mediana é estimada por histograma, não por seleção
exata, então a mediana medida depois não é exatamente a mesma amostra que
entrou. O desvio tem o tamanho do instrumento, não o tamanho de um erro.

**Por que isto importa mais do que parece.** É a primeira verificação da suíte
que não é "hoje é igual a ontem" nem "as duas implementações concordam". É uma
propriedade algébrica da transformação, derivável no papel, conferida contra a
saída. A §7 registra que as medidas do Python validam aritmética e não escolha
de algoritmo, porque a fórmula foi lida daqui — esta identidade não tem essa
limitação, porque não veio de nenhuma das duas implementações: veio da
definição do MTF.

Serve como teste permanente do caminho float. Se um dia `after.median` deixar de
bater com `before.median` no ramo não-linear, alguma coisa entre o cálculo do
midtones e a gravação do pixel passou a arredondar. Vale a pena virar asserção
explícita no harness quando o Módulo 1 acrescentar etapas antes do esticamento —
aí `before` do stretch deixa de ser `before` da cadeia, e a identidade continua
tendo de valer entre os dois campos da mesma etapa.

### `BAYERPAT` manda; a estatística não veta — isto foi um bug
Versão original exigia que o teste de vizinhança (`D1/D2 > 1.15`) confirmasse o
mosaico antes de debayerizar. **Num sub Seestar real isso falha**: razão medida
0,89, contraste de treliça de apenas **2%** sob um piso de ruído cerca de 5×
maior. Resultado: frame colorido saía como mosaico cinza.

O fixture sintético passava com razão 3,23 porque tinha 22% de dominante e
ruído baixo. Era fácil demais. **Lição: fixture sintético valida o parser, não
calibra limiar.**

Regra atual: `BAYERPAT` decide *se* há mosaico. A estatística decide *em qual
diagonal estão os verdes*, e serve de detector só quando não há keyword.

### O flip de ROWORDER não é pré-aplicado ao padrão Bayer
Produtores discordam se `BAYERPAT` descreve o array armazenado ou a imagem
exibida. Pré-aplicar o flip só troca qual classe de arquivo quebra. Como o
espelho vertical é a **única** transformação que move os verdes entre as
diagonais, medir a posição dos verdes absorve a ambiguidade inteira. Ao header
sobra só a distinção que medição nenhuma resolve: qual dos dois sítios
não-verdes é o vermelho.

### Rice: o unquantize tem que ser em double
`ZZERO` = 13353,73 enquanto o valor reconstruído é 0,0225 — os inteiros ficam
empilhados contra o fundo da faixa int32 (primeiro pixel do primeiro tile:
`0x80000082` = −2147483518). Reconstruir 0,0225 subtraindo dois números da
ordem de 13353 custa ~6 dígitos significativos. Number em JS é double, então sai
de graça **desde que o intermediário não passe por um Float32Array**.

Efeito colateral: os inteiros ficam a 129 do sentinela `−2147483647`
("era exatamente 0.0"). Se aparecer pixel preto isolado, é o primeiro lugar a
olhar.

Índice do dither: `(tile + ZDITHER0 − 1) mod 10000`, tabela Park-Miller
(`a=16807`, `m=2³¹−1`, semente 1) gerada em runtime, não embutida.

### Export FITS: linear, pré-esticamento, ordem original, sem `ROWORDER`
Grava o que o `.fz` contém, não o que a tela mostra — gravar o esticado
entregaria ao Siril um arquivo não-linear. As linhas saem na ordem em que
entraram (o flip é desfeito na escrita, sem cópia extra) e **nenhum `ROWORDER`
é adicionado**: como a orientação absoluta está em aberto, injetar o keyword
seria afirmar no arquivo algo ainda não medido.

Cards preservados verbatim, menos os estruturais e os de compressão. Adiciona
uma linha de `HISTORY`, quebrada em limite de palavra (card FITS tem 80 bytes e
`HISTORY ` come 8; a primeira versão estourou e cortou no meio de uma palavra).

### A correção óbvia é pior que o bug — e a tolerância teria calado o instrumento

**O caso.** O pedestal era a mediana da **retícula** do modelo, não do modelo
sobre o quadro. A retícula anda em passo fixo de 8 px, então o último nó cai
**fora da imagem** — 904 num quadro de 900 — onde a spline extrapola. Aqueles
valores entravam na mediana, e como o gradiente cresce para x alto o pedestal
saía alto: **+10 bins** contra a segunda implementação.

**A correção óbvia piora.** "Descarte os nós de fora" leva o viés de **+10 para
−16 bins**: agora falta a borda alta em vez de sobrar. Medido, nas três:

| definição | erro, em bins |
|---|---|
| retícula em passo fixo, ultrapassando a borda | +10,2 / +9,0 / +8,4 |
| **passo fixo, só os nós de dentro** | **−16,0 / −16,9 / −14,0** |
| linspace cobrindo exatamente `[0, N−1]` | 0,28 / 1,37 / 0,68 |
| **mediana sobre os pixels do quadro** | **0,08 / 0,06 / 0,05** |

**A regra geral:** *passo fixo nunca cobre `[0, N−1]` uniformemente a menos que
`N−1` seja múltiplo do passo.* Ultrapassa ou falta, e nos dois casos a amostra é
enviesada — só o sinal muda. Descartar o excedente não conserta; troca de erro.

**O que decide não é qual número bate, é a definição.** O pedestal é a mediana
**do modelo**, e o modelo é o que se aplica ao quadro; a mediana dele é sobre os
pixels do quadro. A retícula existe por razão de custo. Deixá-la definir o valor
foi confundir o instrumento com a grandeza — a mesma forma de [indicador verde
lido como resposta a outra pergunta], num lugar diferente. O `linspace` daria ~1
bin de graça e ainda assim estaria errado: funciona porque cobre a borda por
construção, não porque a definição está certa, e muda o divisor e volta a
divergir.

#### O que a tolerância teria custado

Antes de achar isto, eu propus um termo derivável para o piso da §7 — somar
`|Δpedestal|` às estatísticas de posição, porque `out = in − model + pedestal` e
um deslocamento de pedestal move todo quantil igual. **A derivação estava certa
e aplicá-la teria sido um desastre.**

As 24 comparações que reprovavam passariam — com **9 bins de extrapolação fora
do quadro** por baixo. O defeito ficaria no produto, não no comparador: um
pedestal errado desloca o quadro corrigido inteiro em 1,5e-4, que é 0,04 nível
de 255.

E o pior: **este projeto tem um detector de deslocamento sistemático**, escrito
exatamente para pegar isso, e ele teria pegado. A tolerância nova o teria
silenciado antes.

**A assinatura completa, e é a lição mais cara desta sessão:**

> Tolerância que cresce para acomodar um número que ninguém explicou desliga o
> instrumento que acharia a causa.

Um limite só pode ser afrouxado depois que a diferença está explicada — nunca
para explicá-la. A derivação ser correta não basta: ela justifica *que o termo
existe*, não *que aquele número específico vinha dali*.

### Resultado negativo exige controle positivo antes de virar achado

**Regra.** Quando uma medição diz "não funcionou", a primeira hipótese é o
instrumento, não o objeto. Antes de reportar, rode a mesma medição num caso onde
o resultado é conhecido. Se o controle também falhar, o achado era do
instrumento.

O caso: a auditoria do `index.html` mediu o Chrome headless carregando a página
por `file://` e o pipeline **não completou** — sem erro de JS, sem exceção, com
`state.diag` nulo depois de 6 segundos. Isso tinha tudo para virar "a ferramenta
não roda por duplo clique no Chrome", que é um achado grave e falso.

O controle: a mesma página, o mesmo navegador, o mesmo comando, sobre `http://`.
**Também falhou.** Logo o defeito não era do `file://`.

A causa real: `--virtual-time-budget` do Chrome headless avança o relógio da
thread principal e **não avança os timers de dentro de um Worker**. O pipeline
roda no worker, espera num `await yieldNow()`, e o worker nunca acorda. Medido de
novo forçando o caminho inline — que é o caminho que existe justamente para
`file://` — a página roda completa, nos dois navegadores.

**Por que a regra é barata e a falta dela é cara.** O controle custou uma
execução. Sem ele, o relatório teria dito "não roda no Chrome"; a investigação
seguinte teria começado no Worker, no blob, na política de origem do `file://` —
tudo lugar errado. É o mesmo formato do sintoma que aponta para o lugar errado,
duas seções abaixo, só que auto-infligido.

Vale para qualquer instrumento novo: navegador headless, harness recém-escrito,
comparador recém-mudado. **A primeira vez que um instrumento diz "falhou", ele
está sob suspeita junto com o objeto.**

### A classe mais cara: erro invisível na métrica de saída

Dois bugs do Módulo 1 são a mesma classe, e nenhum dos dois teria sido pego por
nenhum teste desta suíte. **Os dois foram achados por medição, não por teste.**

| | o erro | o que ele fazia |
|---|---|---|
| λ da RBF | escalado por `mean(diag(A))`, que é 0 para thin-plate spline | `smoothing` não fazia nada; o ajuste era o pior da varredura |
| `before` do stretch | medido antes da etapa de fundo, usado depois dela | ponto preto 2,5 a 5× fundo demais, em todo quadro |
| grade encaixada na margem | `edgeMargin` aplicado duas vezes | `rejected-edge` inalcançável; 31% do campo limpo fora do casco |

#### Sub-assinatura: indicador verde lido como resposta a outra pergunta

Dois casos, a mesma forma. Um indicador estava verde, eu li como "está tudo
certo", e ele respondia a uma pergunta mais estreita do que a que eu fazia.

| indicador | o que eu li | o que ele responde |
|---|---|---|
| `rejeitadas por borda: 0`, nos quatro fixtures | "não há amostras na borda" | "este estado é inalcançável por construção" |
| `git status` → *limpo*, em toda rodada da sessão | "está tudo commitado" | "tudo **que é rastreado** está commitado" |

O segundo custou dois fixtures. `fixture-gradient.fit` e `fixture-edge.fit`
casam com `*.fit` no `.gitignore` e a lista de exceções parou nos três
primeiros. Eu os gerei, capturei goldens deles, escrevi o MANIFEST com os
sha256, commitei tudo — e os arquivos nunca entraram no repositório. Num clone
novo, dois dos cinco fixtures não existiriam, dois goldens falhariam por
"fixture não encontrado", e a suíte passaria a **mentir sobre o que cobre**.

**A regra:** para todo artefato que a suíte precisa, ou ele está rastreado, ou
está escrito por que não precisa estar. Não há terceira opção, e "o git não
reclamou" não é uma delas — o git reclama do que conhece.

Agora é verificado em vez de lembrado: `build.ps1 -Check` confere que todo
arquivo referenciado por `capture-golden.js` e por `compare-golden.ps1` está em
`git ls-files`, e reprova se não estiver.

**O padrão que os dois têm em comum, e o que perguntar:** um indicador só
responde à pergunta que ele foi construído para responder. Antes de aceitar um
verde, diga em voz alta qual é essa pergunta. Se a frase sair mais estreita do
que a que você queria fazer, o verde não é a sua resposta.

#### Sub-assinatura: estado documentado que nunca pode ocorrer

O terceiro é os dois primeiros mais uma coisa, e essa coisa merece nome próprio.

A §2.2 define `rejected-edge` como "a caixa cruza a margem de borda". A
implementação encaixava a grade **dentro** da margem e depois testava se a caixa
cruzava a margem. O teste era código que nunca executava o ramo verdadeiro,
**para nenhum valor de nenhum parâmetro**.

E o relatório dizia isso, em todo fixture, desde o primeiro dia:

```
rejeitadas por borda: 0
rejeitadas por borda: 0
rejeitadas por borda: 0
rejeitadas por borda: 0
```

Eu li quatro zeros como "não há amostras na borda destes fixtures". Eram
"este estado é inalcançável". **Um zero é um dado; quatro zeros num campo que
tem um ramo de código são uma pergunta.**

**Por que não falha:** o estado é opcional. Nada quebra quando um enum nunca
atinge um de seus valores — o programa só percorre menos caminhos do que
diz percorrer. O record continua bem formado, o log continua correto, o
tooltip continua funcionando para os estados que ocorrem.

**Por que é caro mesmo assim:** o custo não estava no estado ausente, estava na
causa dele. A grade encolhida deixava 31,4% do campo limpo fora do casco das
amostras, onde a spline extrapola — que é o modo de falha clássico de RBF. Erro
máximo de campo limpo 0,169 contra 0,094 dentro do casco.

**A regra:** para todo estado que uma spec enumera, ou o teste demonstra o
estado ocorrendo, ou está escrito por que ele não pode ocorrer naquele fixture.
Contagem zero persistente num estado enumerado é hipótese a testar, não
observação a registrar.

Depois da correção o estado é alcançável, e foi **demonstrado** em vez de
argumentado: `edgeMargin` 0,05 dispara no `nonlinear` e no `gradient`, 0,06 no
`seestar`, 0,09 no `rice` — exatamente onde a geometria prevê, que é
`margem > w/(2·colunas) − metade da caixa`. Continua zero no padrão de 0,02, e
agora isso é uma propriedade dos fixtures e não do código.

**A assinatura da classe:**

1. **Não falha.** Nenhuma exceção, nenhum `NaN`, nenhum aviso. Sai imagem, sai
   log, sai record.
2. **Não é visivelmente errado.** É pior, não absurdo. Ninguém olhando a imagem
   desconfia.
3. **É invisível na métrica de saída.** Esta é a parte que importa. A mediana
   pós-esticamento fica em ~64 de qualquer jeito, com MADN certo ou 5× errado,
   porque o MTF mapeia mediana no alvo seja qual for o MADN. A métrica que o
   produto usa para dizer "está bom" é justamente cega ao erro.
4. **Só aparece quando outra coisa muda.** O `before` do stretch estava certo
   enquanto a etapa de fundo só amostrava, e virou errado no instante em que um
   pixel se moveu. O bug foi escrito num dia em que era correto.

**Por que a suíte não pega.** `compare-golden` pergunta se hoje é igual a
ontem — e ontem já estava errado. `compare-reference` pergunta se as duas
implementações concordam — e a referência leu a fórmula daqui. Um golden
capturado com o bug dentro vira a definição de "certo", e o harness passa a
defender o erro.

**O que pega, e foi o que pegou os dois:** medir uma grandeza contra algo que
não saiu deste código.

- O λ apareceu numa varredura de `smoothing` contra o gradiente verdadeiro dos
  cards `HISTORY` — `smoothing 0` sendo a pior linha da tabela é o que denunciou
  que a regra literal zerava tudo.
- O `before` do stretch apareceu ao comparar `bg.before.madn` com
  `bg.after.madn` e ver o número que o stretch usava ser o primeiro.

**Regra prática:** quando uma etapa nova entra na cadeia, **imprima as
estatísticas de cada fronteira** — o que cada etapa mediu, e de qual buffer — e
confira que a etapa seguinte está usando a fronteira certa. É a mesma família da
regra do λ, uma seção abaixo: calcule o número e olhe para ele, uma vez, em vez
de confiar que ele é o que você imagina.

### Regra de escala que assume propriedade não verificada do kernel

**Classe de erro.** Uma constante de regularização "escalada por uma propriedade
do operador" está certa só enquanto aquela propriedade for o que se supôs. Se a
suposição for falsa, **não há erro, não há aviso, e o resultado é pior para
sempre.**

O caso: a §2.3 do Módulo 1 mandava escalar `lambda` pela **média da diagonal de
`A`**. Para thin-plate spline a diagonal de `A` é `phi(0) = r² ln r` em `r = 0`,
que é `0`, em toda entrada, por definição do kernel. A regra ao pé da letra dá
`lambda = 0` sempre, e o `smoothing` vira um knob que não faz nada.

O que torna a classe perigosa:

- **Não falha.** `lambda = 0` é um sistema perfeitamente resolvível — é a spline
  interpoladora pura. Sai superfície, sai imagem, sai log.
- **Não é visivelmente errado.** É o pior ajuste da varredura, não um absurdo:
  resíduo máximo 0,245 nível contra 0,168, e absorve 8,49% do objeto contra
  6,27%. Ninguém olhando a imagem desconfia.
- **O knob parece funcionar.** O `smoothing` aparece no record, na UI e no log.
  Um usuário mexeria nele e veria zero diferença, e concluiria que suavização
  não importa nesta ferramenta.

**A regra que teria pego:** antes de escalar por uma propriedade de um operador,
**calcule a propriedade e imprima**. `mean(diag(A))` impresso uma vez teria dado
`0` e a conversa acabaria ali. O custo é uma linha; o custo de não fazer é uma
degradação permanente que nenhum teste desta suíte detecta, porque todos os
testes comparam contra a saída deste mesmo código.

Vale para qualquer normalização por estatística do próprio operador: traço,
diagonal, norma, autovalor dominante, média de linha. **Confira que o número não
é zero, não é infinito, e tem a ordem de grandeza que você imagina** — as três,
e não só a primeira.

O substituto aqui é a média de `|A[i][j]|` fora da diagonal, que é a magnitude
que o kernel de fato tem. Registrado na §2.3 da spec com o número que mostra a
diferença.

### Acoplamento posicional a `records[]` falha em silêncio, e o sintoma aponta para o lugar errado

**Classe de erro, não incidente.** Aconteceu duas vezes no mesmo dia, em dois
arquivos escritos por motivos diferentes, e as duas por escrever `records[0]`
onde o que se queria era "o record da etapa X".

Enquanto a cadeia tem uma etapa, `records[0]` e "o record do stretch" são a
mesma coisa, e o código está certo por coincidência. No dia em que uma etapa
entra na frente, `records[0]` passa a ser outra coisa **sem que nada avise**:

- `run.js` construía o log e o diagnóstico de `records[0].before`. Passaria a
  imprimir a medição da etapa de fundo sob os rótulos do autostretch. O log é a
  entrega do produto.
- `compare-reference.ps1` comparava `records[0].before/after` contra os números
  do Python. Passaria a comparar a etapa errada contra a referência certa.

**O que torna a classe perigosa é o sintoma.** O segundo caso só apareceu como
crash porque a etapa de fundo reporta `after: null` — sorte. Se ela reportasse
uma medição preenchida, o comparador teria produzido **FAIL numérico em 24
campos**, e o FAIL diria "as medianas do canal R divergem da referência". Um FAIL
assim se lê como regressão de pipeline. A investigação começaria no decode, no
histograma, no autostretch — em tudo, menos na linha que escolheu o record
errado. Horas caçando um bug que não existe, num lugar onde ele não está.

**Regra:** record se seleciona por `id`, nunca por posição, e a ausência é erro
explícito e não `undefined` seguindo adiante.

```js
var rec = null;
for (var i = 0; i < records.length; i++) if (records[i].id === 'stretch-mtf') rec = records[i];
if (!rec) throw FitsError('unknown', 'the chain produced no stretch record');
```

Vale para qualquer coleção cuja ordem seja consequência de outra decisão:
`records`, `perChannel` quando o número de canais varia, `CATALOGUE`. A pergunta
que expõe o problema é **"o que quebra quando alguém inserir um item antes deste
aqui?"** — se a resposta for "nada visível, e depois números errados", o índice
tem que virar busca.

### Mediana da caixa, não média — agora com número

A §2.1 do Módulo 1 manda usar a **mediana** da caixa de amostra, não a média,
"para sobreviver a uma estrela dentro da caixa". Era afirmação; passou a ser
medida, no `fixture-gradient.fit`, que traz oito estrelas-sonda em posições
gravadas nos cards `HISTORY`.

Nas caixas que contêm uma sonda, canal G, desvio contra o gradiente verdadeiro,
em níveis de 255:

| | mediana da caixa | média da caixa |
|---|---|---|
| desvio | **0,08 a 0,30** | **5,1 a 5,8** |

Cerca de **20× pior para a média**. A média é puxada pela estrela inteira; a
mediana só se move se a estrela ocupar mais da metade da caixa.

**O que faz o número ser esse, e o que o mudaria.** A sonda tem `sigma` 2,2 e a
caixa tem 625 pixels: a estrela levanta cerca de 22% deles, confortavelmente
abaixo de metade. Uma estrela grande o bastante para cobrir mais de 312 pixels
viraria a mediana também — a mediana não é imune, é robusta até 50%. Se um dia
o `boxSize` encolher ou o seeing do dado real inchar as estrelas, esta margem é
a primeira coisa a reconferir.

O sigma da sonda é pequeno **de propósito**, e isso é uma escolha do fixture,
não uma propriedade do céu: um sigma maior faria o fixture argumentar o
contrário do que a spec afirma.

### Outras
- **Handshake antes de transferir o buffer.** O worker posta `ready`; só então
  o arquivo é transferido. Transferir antes deixaria o buffer destacado e sem
  nada para tentar de novo se o worker falhasse — que é o caso `file://`.
- **Inteiro mantém a escala do container**, nunca é reescalado pelo máximo
  observado: isso seria um esticamento não declarado.
- **`normalisePhysical` é compartilhada** pelos dois leitores (simples e
  comprimido) para que nunca possam discordar sobre o que os números significam.
- **Estatística é subamostrada acima de 8 Mpx** (stride até ~8M amostras). O
  tamanho da amostra fica no diagnóstico; o log não menciona porque a mediana de
  8M amostras é indistinguível da exata.
- **`TOOL_URL` está vazio de propósito.** Enquanto vazio, a primeira linha do
  log só nomeia a ferramenta. Link morto num post público é pior que link
  nenhum. Preencher quando a página tiver endereço.

## Classe: etapa cujo modo de falha é virar identidade

**Uma etapa que pode degradar até não fazer nada precisa de um teste que
desligue as defesas dela e EXIJA que o resultado mude.**

Achado no Módulo 2, na calibração de cor, e é a pior forma de falha que este
projeto encontrou até agora — pior que travar, pior que mensagem errada, pior
que aceitar arquivo corrompido. Todas essas aparecem. Esta não.

O mecanismo: os ganhos saem de razões entre canais medidas numa população de
pixels. Se a população selecionada for errada — saturada, ou o corpo de uma
galáxia — as razões convergem para 1 e os ganhos viram 1,000. Aí:

- a etapa **roda**, não pula
- o record **preenche**, com números plausíveis
- o log **imprime**, e imprime a verdade: os números vieram das estrelas
- `applied: true`, então a linha de negação retira a promessa certa
- e **a cor nunca foi medida**

Nenhum comparador pega isso, porque nada está errado: está tudo igual. Um golden
capturado com o defeito presente fixa o defeito como referência, e a partir daí
a suíte defende o bug.

**O teste que pega é a tabela dos quatro modos**, no `fixture-colour`:

| configuração | R/G | ganho R |
|---|---|---|
| tudo ligado | 1,2511 | 0,7993 |
| sem rejeição de extenso | 1,2513 | 0,7992 |
| sem corte superior | 1,2521 | 0,7987 |
| **sem os dois** | **1,0027** | **0,9973** |

A última linha é a asserção. Não é "o resultado continua certo com as defesas
ligadas" — isso um golden já dá. É **"o resultado fica errado quando eu as
desligo"**, e o valor errado é conhecido: identidade. Se um dia essa linha
passar a dar 0,799 também, ou a etapa parou de depender das defesas (improvável)
ou a seleção parou de acontecer.

As duas linhas do meio não são enfeite: mostram que as duas defesas se cobrem —
o filtro de extenso também rejeita aglomerado saturado, porque borrão saturado
tem vizinhança cheia. Sem elas eu teria concluído que uma das defesas é
dispensável.

**A regra geral.** Para toda etapa cujo resultado *pode* ser a identidade:
existe um controle que desativa o que faz a etapa funcionar e afirma um valor
**diferente** do valor correto. É a mesma família dos controles negativos de
`negative-controls.ps1` — "a checagem ainda consegue reprovar?" — aplicada ao
que a etapa mede em vez de ao que o comparador compara.

Candidatos já visíveis para o mesmo tratamento: a extração de fundo (uma
superfície que virasse constante seria invisível), e o esticamento ligado
(`applyVia: 'luminance'` com deriva de razão zero é o resultado certo **e**
também o que sai se a transferência não for aplicada — ver `colourFidelity`, que
por isso mede a deriva **e** as razões, não só a deriva).

## Regra de publicação: release só quando a saída muda para o usuário

**Commit no master é histórico. Release é anúncio.**

Um release novo só sai quando o que a pessoa baixa **se comporta** diferente. Se
o `index.html` cresceu mas o resultado de processar um arquivo é o mesmo —
etapa nova desligada por padrão, refatoração, comentário, teste — o release
anterior continua correto para quem baixa, e publicar um novo gasta a atenção
das pessoas à toa.

Concreto, e é o caso que gerou a regra: o Módulo 2 acrescentou a calibração de
cor com `colourCal: false`. O `index.html` foi de 160.544 para 189.367 bytes e
**nenhum pixel de saída mudou**. `master` recebeu o commit; o `v1.0.0` ficou.

Consequência operacional: o asset do release **não** acompanha o master, e isso
é de propósito. Quando um release novo sair, o `index.html` anexado tem que ser
o do commit que o release marca — não "o mais recente".

## Classe: duas medições certas que leem como contradição

**Toda frase do log que cita uma contagem tem que dizer o que ela conta.**

Achado no passo 4 do Módulo 3. O log imprimia, com oito linhas de distância:

> 307,796 pixels came out above 1.0 in one channel.

> 0.000% of pixels land on pure black or pure white after the transfer.

As duas eram **verdadeiras**. A primeira conta o estouro — pixels cujo canal mais
forte passou de 1 e que foram divididos pelo próprio máximo. A segunda conta o
corte da curva sobre a **luminância**, e nenhum pixel foi cortado ali. São
grandezas diferentes com unidades parecidas, e nada no texto dizia isso.

Num produto cujo argumento inteiro é "o log é auditável", isto custa mais que um
erro. Um erro numérico o leitor atribui a um bug e reporta. Uma contradição
aparente ele atribui a **desonestidade**, e a única defesa disponível — "as duas
estão certas, são coisas diferentes" — é exatamente o que alguém diria se não
estivessem.

A frase agora diz o que conta e diz que é outra contagem. A regra geral: número
no log sem o predicado dele é um número que vai ser lido contra outro número.

Vale também para o record e para o diagnóstico, mas ali é menos grave — quem lê
JSON lê o nome do campo. O log é prosa e a prosa é onde a ambiguidade mora.

## `JSON.stringify` descarta `undefined`, e foi uma âncora concreta que pegou

Um campo que deixa de ser escrito **desaparece do JSON sem erro nenhum**.

No passo 4 do Módulo 3 o caminho ligado não escrevia `shadows`, `midtones`,
`outLow` e `outHigh` em `before.perChannel` — a curva era uma só, derivada da
luminância, e nada os punha lá. O `buildDiag` lia `s.outLow` e recebia
`undefined`; `JSON.stringify` simplesmente **omite a chave**. Quatro campos por
canal, doze no total, sumiram do diagnóstico sem erro, sem aviso, sem log.

Nenhum comparador pegaria: `compare-golden` teria capturado o diag sem os campos
e fixado a ausência como referência.

**O que pegou, e isso decide uma discussão antiga.** Foi
`negative-controls.ps1`, parando em:

```
pattern not found in nonlinear-fixture.diag.json: "pixelsBlack": 269
```

Um controle ancorado num **valor concreto lido do golden**, não numa asserção
estrutural. Reclamei quatro vezes de ter que reancorar esses literais quando os
goldens mudam — no passo 5 do Módulo 3 saiu o último deles, `"target": 0.25`.
**Foi exatamente a reancoragem que achou o bug.** Uma asserção estrutural
("existe um campo `pixelsBlack`") teria passado, porque a chave existia em algum
lugar; a âncora concreta exigiu *aquele número naquele arquivo*, e ele não
estava mais lá.

Decidido, e não se revisita: **âncoras em valores reais, sempre.** O custo é
reancorar quando o golden muda de propósito. O retorno é que uma mudança que
ninguém pretendia para uma perda silenciosa. O custo é visível e o retorno é
invisível, que é a razão de a decisão ser fácil de errar.

## Uma salvaguarda escrita por precaução achou caso real no dia seguinte

O Módulo 2 ganhou a regra dos 3×: se a menor mediana estelar não estiver pelo
menos três vezes acima do pedestal, a calibração não roda, porque
`(mediana − pedestal) / (referência − pedestal)` fica instável quando o
numerador é uma diferença pequena de dois números grandes.

Foi pedida por precaução, sem nenhum caso concreto na mão.

No dia seguinte, no passo 4 do Módulo 3, ela disparou sozinha num fixture que
existia desde o Módulo 0:

```
Stellar gains: the faintest star median is 0.407718, less than 3x the sky
pedestal (0.246154); a ratio taken above the sky is unstable when the star is
barely above it.
```

O `fixture-nonlinear` já vem esticado — mediana perto de 0,25 — então o pedestal
é enorme em relação a tudo e não existe população estelar separável. A
salvaguarda leu isso corretamente e recusou, com o número medido na frase.

**O argumento para escrever a próxima:** salvaguarda barata, com mensagem que
carrega a medição, encontra caso real antes de a spec descobrir que ele existe.
O custo é uma condição e uma frase; o retorno é a etapa recusando em vez de
produzir um número que ninguém saberia questionar.

## A cascata começa antes de onde o sintoma aparece

Módulo 2, passo 7. Fui mandado investigar **viés na calibração de cor**: os
ganhos das duas implementações diferiam, e no azul a referência estava 6,6×
mais perto da verdade injetada. O sintoma era inequívoco e apontava para a
etapa nova.

Não havia viés nenhum na calibração. **Com o mesmo quadro de entrada, os dois
lados concordam em 7,6e-6** — cem vezes menos que a diferença observada. A
divergência inteira vinha de uma etapa antes, na extração de fundo, e de uma
regra que a referência não tinha: `rejected-clipped`.

O que fecha o caso é que **as quatro divergências colapsam juntas**. Desliguei a
regra na minha ponta, mesma fonte, só a constante neutralizada:

| | com a regra | sem a regra | a deles |
|---|---|---|---|
| amostras aceitas | 49 | **71** | 71 |
| alvo de neutralização | 0,015217205 | **0,015513425** | 0,015513439 |
| rejeitados por saturação | 302.053 | **302.060** | 302.060 |
| rejeitados como extenso | 1.646 | **177** | 177 |
| ganho azul | 1,2509612 | **1,2501524** | 1,2501448 |

Quatro números que discordavam em quatro ordens de grandeza diferentes, e um
interruptor os alinha todos. Uma causa, não quatro.

**A regra de investigação:** quando várias divergências aparecem juntas numa
etapa nova, a hipótese barata não é "a etapa nova tem um viés" — é **"a entrada
da etapa nova é outra"**. Testa-se desligando uma coisa de cada vez a montante
até os números alinharem, e o interruptor que alinha nomeia a causa. Custou uma
medição; a hipótese do viés teria custado a leitura inteira da calibração.

**E a direção do erro não indica quem está certo.** A referência estava mais
perto da verdade injetada nos dois canais, e mesmo assim era ela que tinha o
buraco. O `sweep` de `BG_CLIP_FRACTION` mostrou que o erro contra a verdade
passeia entre 0,01% e 0,11% sem mínimo estável — nenhum ajuste minimiza os dois
canais, e o vermelho não melhora em nenhum. **Estar mais perto da verdade num
fixture não é evidência de correção quando a faixa de ruído do método é maior
que a diferença.** O que decidiu foi medir o envenenamento da mediana da caixa
direto contra a rampa dos cards — ver a tabela na §2.1 do Módulo 1.

## Argumento de projeto verificado num fixture que não o estressa

**"A mediana da caixa sobrevive à estrela"** estava escrito na §2.1 do Módulo 1
como justificativa de por que a amostra é mediana e não média. É falso no caso
geral, e a condição de validade não estava escrita.

Foi calibrado na estrela-sonda do `fixture-gradient`: σ 2,2, amplitude 0,45,
~22% da caixa. Ali sobrevive. Com estrela saturada de pegada grande não
sobrevive, e **não há platô até 50%** — o erro cresce liso desde o começo e em
20–30% já é 700× o ruído da mediana.

É a mesma família dos **quatro zeros do `rejected-edge`**: um número que parecia
confirmar o projeto e só dizia que o caminho nunca tinha sido percorrido. E do
mesmo jeito, só apareceu quando um fixture novo estressou a condição.

**A regra:** todo argumento de projeto escrito numa spec carrega, junto, **o
regime em que foi verificado**. "A mediana sobrevive à estrela" vira "a mediana
sobrevive a uma fonte pontual que ocupe até ~20% da caixa, medido assim". Sem o
regime, a frase é verdadeira no fixture que a gerou e desconhecida em todo o
resto — e ninguém sabe disso até um caso novo chegar.

## Em aberto

**Ordem de linha absoluta para arquivo sem `ROWORDER`.** Nem o `.fz` do Siril
nem os subs da ZWO trazem o keyword; o código assume o padrão do FITS
(BOTTOM-UP) e inverte.

Medido: **stack e subs concordam entre si** — casamento de estrelas com busca em
rotação deu pico 25 no ângulo exatamente 0° na mesma quiralidade, contra 7 em
20° espelhado; e o sinal escala com o número de estrelas (4→6→13→21) enquanto o
espelhado fica plano (2→4→5→8).

Não resolvido: se BOTTOM-UP é a suposição certa. **O PNG processado que veio
junto do stack não serve de referência** — correlação, centróide e casamento de
estrelas com 4 transformações, 5 escalas e busca em rotação, tudo em nível de
ruído. A causa aparece na contagem: a renderização tem 8.663 estrelas
detectáveis, o PNG tem 333. Redução de estrelas pesada; o nome do arquivo sugere
composição por blend.

O que está em jogo é só um espelhamento vertical — não afeta cor, dado nem
medidas, e é aplicado consistentemente aos dois tipos de arquivo. **Como fechar:
um print de como o Siril exibe o mesmo stack.** O jeito rigoroso seria plate
solve contra catálogo, fora do escopo de uma página.

## Harness de teste (`.claude/`, não faz parte da entrega)

- `make-fixture.ps1` — gera os três fixtures de `test/fixtures/`, todos de
  semente fixa e **reprodutíveis byte a byte** (verificado: regerar o
  `fixture-seestar.fit` devolve o mesmo sha256). O seestar traz estrelas de
  **cor conhecida** — uma vermelha, uma verde, uma azul: se R e B trocarem, a
  vermelha sai azul e o erro é visível, não estatístico. O `.fz` é escrito por
  um codificador Rice próprio, inverso exato do `riceDecompress`, com a
  quantização montada de propósito para deixar os inteiros logo acima do piso
  do int32 — é a armadilha de precisão descrita acima, agora com guarda.
- `serve.ps1` — servidor estático em TcpListener (HttpListener exigiria URL ACL
  de admin no Windows). `GET /f/<caminho>` serve qualquer arquivo sob a pasta do
  projeto — e **nada fora dela**; `POST /save/<nome>` grava em `.claude/shots/`,
  que é como as imagens saem do navegador para o disco.
- `notfits.fit` — texto renomeado, para o teste de erro amigável.

Não há node nem python nesta máquina — por isso PowerShell.

Para verificar internos do pipeline no console do navegador:

```js
const src = document.getElementById('pipeline-src').textContent;
const shim = { onmessage: null, postMessage(){} };
new Function('self', src + ';self.__x={findImageHDU,decodeTileCompressed,toNormalisedFloat};')(shim);
```

## Armadilhas já pisadas

**Quantil de dois estágios que conta duas vezes.** Na primeira medição as
medianas não bateram. O erro era o harness, não o decodificador: cada passada
reescaneia o array inteiro, então a contagem de valores abaixo da janela tem que
ser recomputada, nunca carregada da passada anterior. O padrão denunciou — min e
max batiam exatamente, e todas as medianas e MADN estavam baixas, todas dentro
de **uma largura de bin**. Se acontecer de novo, suspeite da medição antes do
código.

**Objeto de resumo carregando o array de pixels.** `normalisePhysical` recebe
`meta` e devolve `summary`, que vai serializado para o diagnóstico. Anexar
`data` a ele clonaria centenas de MB. Estão deliberadamente separados.

**Correlação e centróide não decidem orientação** em imagem astronômica com
curva tonal diferente e gradiente forte. Só casamento de estrelas decide, e só
se as duas imagens tiverem estrelas suficientes.

## Números de referência (para re-verificar)

Medidos com astropy num stack RGB Rice-comprimido de 2160×3840, saído de um
Seestar S30 Pro por Siril 1.4.4 — um arquivo de parceiro de teste, que **não
está mais nesta árvore** e não voltará (CLAUDE.md). Os números ficam porque são
registro de engenharia: se a descompressão Rice quebrar, é contra eles que se
compara.

| canal | mediana | MADN | min | max |
|---|---|---|---|---|
| R | 0.023279 | 0.000151 | 0.022527 | 1.000002 |
| G | 0.020259 | 0.000070 | 0.019993 | 0.811111 |
| B | 0.019927 | 0.000084 | 0.019543 | 0.860846 |

Bate em 6 casas. Se divergir, a descompressão quebrou — ou a medição.

Desempenho: 24,9 Mpx em 11.520 tiles descomprimidos em ~510 ms; pipeline
completo do `.fz` em ~1,0–1,9 s; escrita do FITS de 95 MB em ~190 ms; M45 de
313 MB em ~1,3 s de pipeline.

## Lacunas conhecidas no suporte a `.fz`

Só `RICE_1`. `.fz` que misture tiles gzip ou use outro `ZCMPTYPE` recebe
mensagem específica dizendo o que é e o que fazer, em vez de tentar adivinhar:
pixel plausível e errado é pior que recusa clara numa ferramenta que existe para
provar processamento.

## O caso "resultado decepcionante" (diagnóstico, sem atribuição)

Um stack S30 Pro de um parceiro de teste chegou com a queixa de resultado
decepcionante. O stack tem MADN de 0,00007 no verde contra mediana 0,02025,
então o autostretch sai com midtones 0,00059 — brutal, e correto para o dado. A
renderização mostra um gradiente de poluição luminosa dominando o quadro. O
problema provavelmente é gradiente não extraído, não esticamento. Não
investigado.

Vale como classe de caso, não como cliente: **MADN muito pequeno contra mediana
pequena produz midtones de três zeros, e o que aparece na tela é o gradiente.**
É o argumento mais forte a favor da extração de fundo do Módulo 1.

## Decisões de publicação — 2026-09-07

### Os fixtures ficam versionados, e o motivo derrubou o meu argumento

Eu propus regerar em vez de versionar: o `make-fixture.ps1` é determinístico, o
`MANIFEST` traz os sha256, e cortaria 42 dos 62 MB. O contra-argumento é melhor
e é o que vale:

**O determinismo foi verificado numa máquina só.** Entre máquinas, com C# e
ponto flutuante, é provável — não garantido. Versão do .NET, versão do
PowerShell, e a geração usa `Math.Exp`, `Math.Log` e `Math.Cos`, que não são
obrigadas a dar o mesmo bit em toda implementação.

**O modo de falha é o que decide.** Se o gerado divergir na máquina de quem
verifica, o sha256 não bate e a pessoa fica sem poder verificar **nada** — não
só aquele fixture. E isso acontece exatamente com quem duvida e foi conferir,
que é a única pessoa para quem esta suíte existe. Os 42 MB compram imunidade a
esse modo de falha.

**Sobre o crescimento do repositório**, que era o meu motivo real: ele vem dos
goldens, não dos fixtures. PNG não deltifica, e recapturei cerca de dez vezes
numa sessão — o `.git` foi a 103 MB com 23 commits. Os fixtures são estáveis; os
goldens é que se repetem.

**Regra adotada:** recaptura de golden vira **commit próprio, com o motivo
escrito**. Não entra de carona num commit de código. Assim o histórico diz
quantas vezes os goldens mudaram e por quê, e o custo fica visível em vez de
diluído.

### O histórico não é reescrito

`Justyear <noreply@justyear.invalid>` fica em todos os commits. Dois motivos, e
o segundo é o que fecha:

- **"Justyear" lê como projeto, não como hobby de uma pessoa.** Para um
  repositório de produto isso é melhor que um nome próprio.
- **Reescrever depois que alguém clonou quebra o clone dessa pessoa.** Os
  hashes mudam, o `git pull` diverge, e o custo cai em quem confiou primeiro.

Isto encerra a questão levantada acima em [Identidade do git deste
repositório]: sim, estes commits não vão ligar a um perfil do GitHub, e não,
não vamos consertar isso. **Não voltar a esta decisão.**

## Identidade do git deste repositório

Configurada **só localmente** (`git config`, sem `--global`):

```
Justyear <noreply@justyear.invalid>
```

`.invalid` é um TLD reservado pela RFC 6761: não resolve, não é registrável, não
liga a perfil nenhum. A alternativa considerada era
`<usuario>@users.noreply.github.com`, o formato legado de e-mail privado do
GitHub, que **ligaria estes commits ao perfil automaticamente** no dia em que a
conta existisse. Foi descartada por causa do modo de falha: sem a conta criada,
o endereço não é seu, e se outra pessoa registrar o username antes, os commits
passam a apontar para o perfil dela — em silêncio, sem erro nenhum. A `.invalid`
falha de forma explícita (commit sem perfil ligado) e conserta quando se quiser.

**Consequência a saber antes de criar conta no GitHub:** o GitHub dá o endereço
canônico `ID+usuario@users.noreply.github.com`, com o ID numérico que só existe
depois da conta. Commits novos ligam sozinhos; **estes não**, e não dá para
adotá-los adicionando o endereço à conta, porque o GitHub exige verificação por
e-mail e `.invalid` nunca recebe. Adotar exige reescrever histórico. Com poucos
commits e sem remote é um `--amend`; com anos e vários branches é `git
filter-repo`. Decidir cedo custa menos.

## Um commit emendado não some sozinho

`git commit --amend` deixa o commit antigo pendurado, alcançável pelo reflog, com
o autor antigo intacto. Ele não vai num `push` — não está em branch — mas vai
numa cópia da pasta, num `git bundle --all` e num clone por sistema de arquivos.
Some com:

```
git reflog expire --expire=now --expire-unreachable=now --all
git gc --prune=now
```

E confere com `git log --all --reflog --format='%h %ae'`, **não** com
`git log -S`: o `-S` procura conteúdo, e autor é metadado — ele daria zero antes
e depois, provando nada.

## Dado de terceiro nesta árvore

Não há, e não pode haver. Os fixtures são sintéticos e gerados por
`.claude/make-fixture.ps1`. A regra — pixel e texto — e o reforço no
`.gitignore` estão em `CLAUDE.md`.

Os arquivos de parceiro que estavam aqui saíram, junto dos goldens derivados
deles. Os originais foram **movidos para fora de qualquer pasta de projeto, não
apagados**; os derivados (renders, goldens, o `.fit` descomprimido que a própria
ferramenta exportou) foram apagados, porque são reproduzíveis a partir do
original e não valia mantê-los.

**O que nenhuma regra deste repositório alcança:** a transcrição da sessão, que
o Claude Code grava fora da árvore. Ela registra tudo que entrou na conversa —
inclusive saída de comando que imprimiu header de arquivo de cliente. O controle
que funciona é a montante: não trazer o dado para dentro da sessão. Auditar
depois é conserto, não prevenção.
