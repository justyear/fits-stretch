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

## O comparador obedece a declaração da referência, não uma lista própria

Aprovado no passo 7. Quando a referência Python não cobre um fixture — hoje o
`seestar`, porque ela não faz debayer e num mosaico mede o padrão Bayer em vez
do quadro demosaicado — **quem declara isso é ela**, num bloco `cobertura` do
próprio JSON:

```json
"cobertura": { "porCanalAindaNA": ["seestar"], "motivo": "..." }
```

O `compare-reference.ps1` lê esse bloco. Não mantém lista de exclusão do lado de
cá.

**Por quê, e não é elegância.** Uma lista aqui seria a segunda cópia da mesma
verdade, e a que envelhece: a referência ganha cobertura, ninguém lembra de
apagar o nome daqui, e o comparador segue pulando um fixture que já podia ser
comparado. Cobertura que existe e não é usada é indistinguível de cobertura que
não existe.

**E a falha é ruidosa nos dois sentidos.** Quando a referência foi reescrita no
passo 7 ela veio sem o bloco `cobertura`, e o `seestar` imediatamente reprovou
em quatro linhas — `fundo.aceitas` 73 contra 81, `lum.madn` por um fator de 6.
Isso é o comportamento certo: parar de declarar uma exclusão faz o comparador
comparar duas coisas que não são a mesma, e reprovar alto. Uma lista local teria
continuado pulando em silêncio e o buraco ficaria invisível.

Mesma família da regra dos hashes do MANIFEST e do `Test-Tracked`: **o dado mora
num lugar só, e quem precisa dele lê de lá.**

## Alimentar uma fórmula com as entradas da outra separa fórmula de entrada

**Quando duas implementações divergem, isso é a primeira medição, não a última.**

Recomputar a grandeza com a **minha fórmula** e as **entradas da outra ponta**, e
comparar o resultado com o valor dela, responde uma pergunta sozinha: *a fórmula
é a mesma?* A outra — *as entradas são as mesmas?* — já está respondida nas
linhas que comparam as entradas.

Custa uma linha de código e decide para que lado investigar.

**Onde funcionou.** `midtones` divergia no `fixture-colour` e no `nonlinear`.
Alimentada com as entradas deles, a minha fórmula reproduziu os valores deles a
**2,8e-17** nos dois. Fórmula idêntica, então o defeito estava numa entrada — e a
entrada era o `target`, que no ramo não-linear é a mediana do próprio quadro e
não o parâmetro. A referência não tinha o ramo não-linear. Localizado em uma
medição.

**Onde não foi feito, e quase custou.** No mesmo dia, o `shadows` do mesmo
fixture divergia em 252 bins, e a hipótese levantada foi *convenção de
percentil* — nearest-rank contra interpolado, `>=` contra `>`. Eu ia investigar
o mecanismo do `cumulativeAt`. Não era nada disso: era **a mesma causa do
`target`**, o ramo não-linear ausente. Quando ele entrou, o `shadows` andou de
0,233590454 para 0,237432778 sozinho, contra os 0,237430381 daqui — **0,16
bins**. Nada foi tocado do lado do percentil e não precisava.

**A assimetria que torna isso barato:** a propagação AMPLIFICA. No
`fixture-colour`, 1,9e-6 de diferença na mediana vira 2,4e-4 em `midtones` —
131× — porque a MTF é íngreme onde `midtones` vale 0,10. Um valor derivado
divergindo muito **não** significa que o método divergiu muito; pode ser uma
entrada divergindo pouco. Sem separar as duas perguntas não há como saber, e a
tentação é alargar a tolerância até caber, o que esconderia uma divergência de
fórmula junto.

**A regra:** divergência num valor **derivado** não se investiga pelo mecanismo
antes de recomputá-lo com as entradas do outro lado. Se bater, o defeito está
numa entrada e o mecanismo está certo — e a entrada tem nome, aparece numa linha
própria do comparador, e é onde a investigação começa.

É a versão local da classe "[a cascata começa antes de onde o sintoma
aparece]": lá a causa estava uma etapa a montante, aqui está uma variável a
montante. Mesmo erro de foco, mesma correção.

## Salvaguarda com constante escolhida sem medir é palpite com aparência de rigor

A calibração de cor teve, por um dia, esta regra: **a menor mediana estelar tem
que estar pelo menos 3× acima do pedestal, senão a etapa não roda.** A
justificativa escrita era "a razão fica instável quando o numerador é uma
diferença pequena de dois números grandes", que é verdade em geral e não diz
nada sobre onde fica o limite.

O `3` não foi medido. Foi escolhido.

**O que ele bloqueou.** Um empilhamento de 60 horas com cor perfeitamente boa. A
razão saiu em 1,87× e a regra recusou ganhos de **R 1,038 · G 1,000 · B 1,341**
— valores confirmados por outro caminho contra o arquivo cru.

**E a razão não estava instável.** Medido, perturbando o pedestal:

| erro no pedestal | ganho azul se move |
|---|---|
| 2 % | 0,60 % |
| 5 % | 1,55 % |
| 10 % | 3,29 % |
| 25 % | 10,2 % |

O erro **real** do pedestal, entre duas implementações independentes, é
**0,048 %** — onde o ganho azul se move menos de 0,02 %. A salvaguarda defendia
contra um erro quatrocentas vezes maior que o que acontece.

### A forma certa: medir a grandeza que a salvaguarda alega proteger

```
Perturbe o pedestal em ±10% e refaça a conta.
Se qualquer ganho se mover mais que 5%, recuse.
```

Derivável, sem constante inventada no meio, e mede **instabilidade** em vez de
usar um múltiplo como procuração dela. Onde a estrela está mesmo colada no céu,
`above` é pequeno, a perturbação é uma fração grande dele, e o mesmo teste
reprova sozinho.

O número medido entra no record e no log: *"a 10% error in the sky estimate
would move the gains by at most 0.23%"*. O leitor julga a resposta em vez de
aceitá-la.

### O efeito colateral, e ele é da outra classe já registrada

Depois da troca, **nenhum** dos seis fixtures faz a regra disparar — todos ficam
entre 0,03 % e 1,3 %. Isso é o resultado certo e cria o problema dos quatro
zeros do `rejected-edge`: salvaguarda que nunca dispara é salvaguarda que
ninguém verificou.

Coberto por `test/compare-safeguards.ps1`, que soma céu ao quadro até a regra
recusar. Somar uma constante não muda `above` — pedestal e mediana estelar sobem
juntos — mas aumenta a sondagem, que é 10 % do pedestal. É o caso físico exato,
não um número forçado:

```
ceu +0.00  sensibilidade 0.103%  aplica 1.0133/1.0000/0.9837
ceu +0.05  sensibilidade 0.504%  aplica
ceu +0.10  sensibilidade 1.140%  aplica
ceu +0.15  sensibilidade 2.305%  aplica
ceu +0.20  sensibilidade 5.088%  RECUSA
ceu +0.30  sensibilidade inf     RECUSA
```

E a asserção que importa mais que o corte: **os ganhos derivam 0,266 % enquanto
a regra ainda aceita.** Se derivassem junto com o céu, a regra estaria recusando
por *diferença* e não por *não-confiabilidade* — mediria outra coisa com o nome
certo.

### As duas defesas podem brigar entre si

O que produziu o 1,87× não foi o céu alto: foi a **rejeição de fonte extensa**
removendo 385 mil pixels — a galáxia inteira — e deixando estrelas de campo
fracas. Uma defesa remove o objeto brilhante, a outra reclama que o resto está
fraco.

Ninguém escreveu isso: as duas foram pedidas separadamente, cada uma com bom
motivo, e a interação apareceu no dado. **Salvaguarda nova entra medindo o que
ela faz com as que já existem**, não só o que faz sozinha.

## A regra funcionou sem ninguém precisar lembrar dela

Passo final do Módulo 3. Depois de trocar a salvaguarda, a instrução foi: *"rode
o M31 de novo e me mande a imagem"*.

Recusei, e o motivo não foi julgamento próprio — foi o `CLAUDE.md` deste
repositório, escrito nesta mesma árvore: nenhum arquivo de terceiro entra, **e
render de dado de parceiro é dado de parceiro**. O `serve.ps1` também não mapeia
nada fora da pasta, que é a metade mecânica da mesma regra.

O que ficou registrado como valendo mais que a recusa: **quem escreveu a regra
não teve que lembrar dela.** Ela foi aplicada contra o pedido de quem a
escreveu, num momento em que atendê-lo era mais rápido e mais agradável, e o
custo de aplicá-la foi um parágrafo.

Isso é o teste que uma regra operacional tem que passar para valer alguma coisa.
Uma regra que só é seguida quando ninguém está pedindo o contrário é decoração;
o que a torna real é ela segurar exatamente quando pesa. As três regras de
higiene de dado deste projeto — a de pixel, a de texto, a de saída de comando —
existem porque uma auditoria já achou centenas de ocorrências de identificador
numa transcrição, e o conserto foi caro. Esta é a primeira vez em que uma delas
evitou o problema em vez de reparar.

**E a alternativa útil existia e foi oferecida:** dos números que a outra ponta
já tinha medido, dava para afirmar que a regra nova admite aquele quadro — 10%
de erro no pedestal move o azul 3,29%, abaixo do corte de 5%. A recusa não
precisou vir sozinha; veio com a resposta que a pergunta queria.

## Preferência aplicada sob restrições medidas

A formulação, e ela é mais apertada que "é gosto".

O Módulo 4 é a primeira etapa deste pipeline que **não mede nada**. O teste que
resolve: pergunte *"qual é a saturação verdadeira deste objeto?"* — a pergunta
não tem resposta. O gradiente **está** no quadro. A razão de fluxo estelar **é**
propriedade dos fótons. Não existe uma saturação que o céu tenha e que a
ferramenta esteja recuperando.

O `amount: 1.45` não desfaz isso. Ele foi medido — de uma entrega manual, §1 da
spec — e **o que essa medição mediu foi o que uma pessoa escolheu**. É medição
precisa de um gosto.

**Mas a etapa não é gosto solto, e a formulação certa é esta:**

> É uma **preferência aplicada sob restrições medidas**. A máscara de SNR e a
> queda nas altas luzes **não são gosto** — "não amplifique onde não há sinal" é
> afirmação sobre ruído, e "não empurre além de onde um canal satura" é
> aritmética. As restrições **impedem a preferência de mentir**. Elas **não a
> convertem em medição**.

A consequência é operacional e vale para o texto: **o log não pode usar a
máscara medida para insinuar que a etapa é medida.** Um produto que satura,
explica a máscara em detalhe e nunca diz "esta parte é uma escolha" usou
medição como cobertura. Por isso a última linha do bloco fica, e não se suaviza:

> This is the one step here that is a preference rather than a measurement, and
> it says so.

## Verificação cujo valor esperado coincide com "nada aconteceu"

**Uma verificação assim só vale com controle negativo, e ela verifica a
implementação, nunca o desenho.**

Achado três vezes no Módulo 4, e as três estavam na spec como se fossem provas:

| verificação | por que é teorema |
|---|---|
| deriva de matiz | `ch' = Y + (ch−Y)k` escala toda diferença entre canais por `k`, e matiz depende só de razões dessas diferenças |
| `k = 1` no fundo | a máscara põe `w = 0` abaixo de `snrLow`, por definição |
| ruído de croma do fundo | mede exatamente o conjunto que a máscara protege — **o mesmo limiar define os dois** |

Nos três, **zero é o resultado certo e também o que sai se a etapa não fizer
nada**. É a mesma família da classe já registrada sobre etapa cujo modo de falha
é virar identidade, e do `colourFidelity` do Módulo 3.

**O que se faz com isso, em ordem:**

1. **Medir a grandeza por um caminho independente do que a produziu.** A deriva
   de matiz é calculada do trio RGB (HSV) e não da decomposição Y–C. Assim um
   `k` por canal, um erro de sinal, um índice trocado aparecem em vez de se
   cancelarem com eles mesmos.
2. **Escrever no record o que a verificação é.** O campo carrega a frase
   *"preserved by construction; this measures the implementation, not the
   design"*. Um zero sem essa etiqueta é lido como evidência de que o desenho
   está certo.
3. **Provar que dispara.** Injetar o defeito e medir. Azul escalado por `k×1.02`
   em vez de `k`: deriva **2,35e-3** contra o limite 1e-6, 2350× acima.

## A alavanca do controle negativo não é o parâmetro óbvio

Corolário do anterior, e custou duas tentativas.

Para fazer a salvaguarda de ruído de croma disparar, o óbvio era **baixar o
`snrLow`** para a máscara parar de proteger. Não funciona: o conjunto que a
salvaguarda **mede** é definido pelo mesmo limiar que a máscara **usa**, então
baixar `snrLow` **esvazia** o conjunto medido em vez de desprotegê-lo. Resultado:
`pixels: 0`, nada a medir, não dispara.

O segundo óbvio era **um quadro de céu sem sinal**, que a §5 da spec pede. Também
não funciona, e pelo mesmo motivo invertido: com todo pixel abaixo do limiar,
todo pixel é protegido e o crescimento é zero. **Um céu sem sinal é o oposto de
fazê-la disparar.**

A alavanca certa era **a fiação da máscara** — o clamp do `w` invertido, que é a
classe de defeito que a salvaguarda existe para pegar. Aí ela dispara: **45,00%**
contra o limite de 2%, e a etapa recusa.

**A regra:** a alavanca de um controle negativo é o **mecanismo que a
salvaguarda alega proteger**, não o parâmetro que dá nome a ele. Quando os dois
coincidem, mexer no parâmetro move a medição junto e não prova nada.


**O controle é permanente desde o passo 8**, em `test/compare-safeguards.ps1`:
três fontes rodadas pela mesma cadeia do golden `saturation-fixture` — a
publicada, o clamp invertido, e o azul com `k` próprio. O comparador exige que
pelo menos uma aplique e pelo menos uma recuse, que quem recusa recuse **pelo
motivo do ruído de croma** e não por outro qualquer, e que exista **exatamente
uma cópia do clamp** no código-fonte. Enquanto era demonstração de sessão, a
salvaguarda era afirmação; agora é controle.
## Salvaguarda que duplica a aritmética que verifica

O controle negativo acima achou um defeito que nenhum teste da suíte acharia.

A pré-passada do ruído de croma **duplicava** o cálculo do `k`. Injetei o clamp
invertido, ele atingiu só o laço principal, e a pré-passada — ainda correta —
previu `k = 1` no fundo, não viu crescimento, aprovou, e o laço principal
aplicou a máscara quebrada. **A salvaguarda estava medindo uma função diferente
da que ia rodar.**

Consertado com uma função só, `satFactor`, chamada pelas duas. E o controle
negativo agora tem uma asserção a mais: **existe exatamente uma cópia do clamp
no código-fonte**. Se aparecer uma segunda, o teste para.

É a mesma classe do `records[0]` e da nota sobre duas medições da mesma coisa
que podem discordar — com um agravante: aqui a segunda cópia era justamente a
que verificava a primeira, então a divergência entre elas era invisível por
construção.

## `announce: false` retira a promessa nas duas direções

A §4 do Módulo 4 pede `announce: false` para a saturação, no argumento de que o
log dedica um bloco a ela. **O argumento não fecha, e a medição mostra por quê:**

| estado | com `announce: false` | |
|---|---|---|
| rodou e aplicou | não nega, bloco descreve | ok |
| rodou e recusou | não nega, bloco diz o motivo | ok |
| **não rodou** | **não nega, sem bloco** | **quebrado** |

A terceira linha é o estado de hoje e o de qualquer build com a saturação
desligada. A palavra sairia da promessa **sem que nada tivesse sido feito** — a
ferramenta pararia de afirmar que não satura, num quadro que ela não saturou.

O esticamento e a calibração nunca caem nessa linha: rodam em todo quadro de
três canais. **A saturação é a primeira etapa que pode simplesmente não existir
na cadeia**, e para ela o padrão do catálogo — anunciar — já produz a frase
certa nos três casos, porque `notAppliedLabels` derruba o rótulo no instante em
que um record reivindica `applied`. Não precisou inventar nada.

**A regra:** `announce: false` pressupõe que a etapa **sempre roda**. Para uma
etapa opcional, ele troca uma promessa verdadeira por silêncio.

## O título reporta o número medido, não o teto

A frase de abertura do bloco da saturação podia dizer duas coisas verdadeiras, e
só uma delas responde à pergunta que o leitor faz.

| candidata | o que é | o que o leitor conclui |
|---|---|---|
| "chroma was scaled by ×1.45" | o **teto** — o parâmetro `amount` | que todo pixel foi multiplicado por 1,45 |
| "chroma was scaled by up to ×1.440" | o **`maxK` medido** neste quadro | que 1,440 foi o máximo que algum pixel recebeu |

O teto é o número que a pessoa escolheu; o `maxK` é o número que o quadro
recebeu. **Um parâmetro não é uma medição, e imprimir o parâmetro no lugar da
medição converte a configuração em resultado** — exatamente o movimento que a
§4 proíbe para esta etapa.

A saída ficou com os dois, nessa ordem: `up to ×1.440 (the ceiling in use is
×1.45)`. O medido primeiro porque é o que aconteceu; o teto ao lado porque sem
ele o leitor não sabe se 1,440 é perto ou longe do que a etapa podia fazer. E a
diferença entre eles não é enfeite: **ela mostra que a máscara mordeu**. Se
`maxK` viesse exatamente no teto em todo quadro, a máscara não estaria
selecionando nada.

Classe: **quando um número de configuração e um número medido são próximos, é
tentador imprimir o de configuração — é mais redondo. O medido é o que o log
deve.** Mesmo motivo pelo qual o bloco do esticamento imprime `stretch` resolvido
e não o alvo pedido.

## Um campo certo que responde a outra pergunta

`pixelsAtFullAmount` conta `w ≥ 1` **e** `roll ≥ 1` — o que a §3 pede, e é a
resposta certa para *"quanto do quadro recebeu o amount inteiro"*. Medido no
`fixture-colour`: o limiar de `snrHigh` cai em Y = 0,798 e o joelho em 0,80,
então a faixa onde os dois saturam tem **0,002 de largura**. O campo dá **0,06%**
e lê como *"a máscara mal engatou"* — quando ela está em `w = 0,927` na faixa do
pico.

O campo não está errado. Ele responde a uma pergunta que quase ninguém está
fazendo, e o leitor faz a outra: *"o sinal forte foi reconhecido pela máscara?"*

A correção foi **acrescentar `pixelsAtFullMask`** (só `w ≥ 1`) e deixar os dois,
não trocar um pelo outro. Trocar teria apagado o que a spec pede; deixar só o da
spec teria mantido um número que engana sozinho.

É a mesma família de "duas medições certas que leem como contradição", com a
diferença de que aqui **o conserto é acrescentar, não escolher**: quando dois
números são ambos verdadeiros e um deles é lido errado sozinho, publique os
dois com os rótulos que separam as perguntas.

## Duas verificações que não são a mesma verificação

A saturação tem duas salvaguardas, e cada uma é cega para o que a outra pega.
Isso não era argumento antes de o controle negativo medir; agora é, e os números
estão no golden.

| fonte rodada pela mesma cadeia | ruído de croma | deriva de matiz |
|---|---|---|
| código publicado | −1,05e-9% (passa) | 1,11e-16 (passa) |
| clamp do `w` invertido | **45,00% → recusa** | não chega a medir |
| azul com `k` próprio (`k×1,02`) | −1,05e-9% (passa) | **2,35e-3 → 2350× o limite** |

A linha do azul é a que vale. O crescimento de croma dela é **idêntico ao do
código publicado, dígito por dígito** — a quebra está só no laço principal e a
pré-passada nem a vê. A salvaguarda de ruído não está sendo tolerante: ela é
**estruturalmente cega** para um erro por canal.

E a linha do clamp invertido mostra o inverso: a etapa recusa **antes** de
escrever qualquer pixel, então a deriva de matiz nunca chega a ser calculada. A
verificação de matiz não teria pego esse defeito nem se tivesse rodado, porque
lá o `k` errado é o mesmo nos três canais e matiz é preservado.

**A regra:** duas salvaguardas numa etapa só se justificam se alguém mostrou uma
falha que passa por uma e é pega pela outra. Sem isso, uma delas é redundante e
ninguém sabe qual. O comparador afirma essa independência explicitamente — se um
dia as duas passarem a pegar as mesmas falhas, `test/compare-safeguards.ps1`
reprova e diz qual sobrou.

## Classe: divergência de precisão e divergência de definição

**Duas implementações podem discordar por dois motivos que não têm nada em
comum, e o diagnóstico de um não funciona no outro.**

| | divergência de **precisão** | divergência de **definição** |
|---|---|---|
| as duas medem | a mesma grandeza, por caminhos diferentes | **grandezas diferentes** |
| exemplo | mediana do histograma de 65536 bins contra mediana exata | desvio da norma contra desvio das componentes empilhadas |
| como aparece | diferença pequena, com tamanho previsível | diferença de tamanho arbitrário, sem causa legível |
| o que resolve | tolerância derivada do instrumento | **nada** — uma das duas definições tem que mudar |

Isto importa porque este projeto já gravou uma técnica boa: *alimentar uma
fórmula com as entradas da outra separa "fórmula diferente" de "entrada
diferente"*. Ela funcionou no `shadows`, no `midtones` e no ganho azul.

**Ela só funciona quando as duas medem a mesma grandeza.** Alimentada com
entradas iguais, uma definição diferente devolve um número diferente — e o
diagnóstico conclui "fórmula diferente", que é verdade e é inútil, porque não
diz *qual* das duas está descrevendo a coisa errada. Pior: alargar a tolerância
até caber faz a divergência sumir e a discordância continuar.

**O que separa os dois casos é ler a outra implementação antes de comparar** —
uma leitura em vez de uma rodada. No Módulo 4 isso achou três divergências de
definição antes de qualquer número chegar: ver "Ler a outra implementação antes dos números chegarem", abaixo.

**E onde as grandezas diferem de propósito e vão continuar diferindo, a saída é
afirmar os dois lados contra o limite que o produto promete** — croma ≤ 2%,
matiz ≤ 1e-6 — e não um contra o outro. A afirmação contra o limite é o que
resta de conteúdo quando a comparação direta não significa nada, e é o mesmo
padrão que o `colourFidelity` do Módulo 3 já usava.

## Classe: zero contra zero não é acordo

**Uma linha `0 | 0 | PASS` diz "conferimos e batem". Às vezes o que aconteceu
foi "não há o que conferir", e as duas são indistinguíveis na saída.**

O caso: as duas implementações da saturação tratam o subfluxo — o pixel que
cairia abaixo de zero — e discordavam de ordem. A referência corrigiu e agora
as duas seguem a mesma ordem. Mas `pixelsLifted` é **0 nos dois lados em todo
fixture que roda a etapa**, então o caminho nunca executou de nenhum dos dois.
A concordância é de projeto, não de medição.

Sem uma linha dizendo isso, o comparador **mente por silêncio**: ele produz uma
linha verde que um leitor entende como cobertura, e a cobertura não existe. É a
mesma classe dos quatro zeros do `rejected-edge` e da salvaguarda que nunca
disparou — com a diferença de que aqui o zero está do lado de fora, na saída do
teste, onde ele parece um resultado.

**A regra:** quando os dois lados dão zero numa contagem, o comparador tem que
decidir entre duas frases e escrever a certa:

- *"os dois contaram e deu zero"* — o caso existe e ninguém caiu nele: é
  medição, e a linha é PASS.
- *"o caminho não foi exercitado"* — não há caso: a linha é **N/A com o motivo
  escrito**, nunca PASS.

Distinguir as duas custa uma condição no comparador. Não distinguir custa a
confiança em todas as outras linhas verdes, porque o leitor deixa de saber
quais delas são medição.

## Ler a outra implementação antes dos números chegarem

A referência do Módulo 4 chegou antes dos dois fixtures que ela precisa para
rodar. Em vez de esperar, li o `saturate()` linha a linha contra o
`saturation.js` — e saíram **três diferenças de definição**, nenhuma delas de
precisão:

| | aqui | na referência (antes da correção) |
|---|---|---|
| `chromaNoise.sigma*` | desvio padrão da **norma** `√(cr²+cg²+cb²)`, um escalar por pixel | desvio padrão das **três componentes empilhadas** num array de 3N |
| ordem do estouro | subfluxo primeiro, levantando os três e **reescalando para preservar Y**; depois o transbordo | transbordo primeiro; depois um levantamento que **não** preserva Y, e um `clip` por canal no fim |
| saturação HSV da tabela | `(max−min)/max` sempre que `max > 0` | zerada quando `max ≤ 0,03` |

Nenhuma delas apareceria como "divergência" legível. A primeira daria dois
números diferentes sem causa visível. A terceira reprovaria só nas faixas
baixas, que é onde se procuraria erro de esticamento antes de erro de
definição — e o piso caía justamente na faixa escura, que é **onde a salvaguarda
de ruído mora**. A segunda não apareceria de jeito nenhum, porque o caminho não
é exercitado: ver "Classe: zero contra zero não é acordo", acima.

As três foram fechadas na referência. **O registro fica porque o custo evitado
não foi o conserto — foi as três rodadas que teriam sido gastas procurando erro
de precisão onde não havia nenhum.** A classe está em
"Classe: divergência de precisão e divergência de definição", acima.

Detalhe que vale por si: a expectativa declarada antes da leitura era *"o sigma
de croma vai divergir porque o meu é exato e o seu sai do `analysePlane`"*.
Estava errada no mecanismo — **as duas somas são exatas sobre os pixels
protegidos**. O que sai do histograma é a mediana e o MADN que decidem *quais*
pixels entram no conjunto. A previsão certa pelo motivo errado teria fechado a
investigação no lugar errado.

## Comparador exercitado com referência sintética antes da real

O bloco novo do `compare-reference` ficaria 100% N/A até os fixtures chegarem —
ou seja, entregue sem nunca ter produzido uma linha. Um comparador nessas
condições é a mesma coisa que uma salvaguarda que nunca disparou.

Ensaio: goldens descartáveis (`-Golden`, que existe para isto), um record de
saturação real injetado no `colour-fixture`, e um bloco `saturacao` na
referência com os números **perturbados de propósito**. Saíram **36 linhas**,
todos os ramos passaram por dados, e a única FAIL foi a perturbação injetada.

E o ensaio se repetiu depois que a referência corrigiu as três definições, com
**a falha injetada mudada de lugar de propósito**: ela foi para o `croma.sigma`,
que é exatamente a linha que deixou de ser `N/A` e passou a ser comparação.
Reprovou em 5,56 de 4,00 bins. Uma linha que muda de veredito possível tem que
ser vista falhando *na condição nova*, não na antiga.

**A regra:** um comparador cujo primeiro dado real é também a primeira vez que
ele roda está sendo estreado e verificado no mesmo instante, e não dá para saber
qual dos dois falhou.

## Classe: módulo que escreve artefato no nível do módulo

**Um módulo que grava arquivo fora de `if __name__ == '__main__'` transforma toda
importação numa execução.** Quem escreve `from chain import load` para pegar uma
função roda o script inteiro como efeito colateral — e sobrescreve o artefato.

O caso: `chain.py` gerava `referencia-cadeia.json` no nível do módulo. Um script
de verificação importou `load` dele, a geração inteira rodou de novo, e a versão
de 4 fixtures sobrescreveu a de 8.

**O sintoma é o que torna isto uma classe e não um descuido.** Não houve erro,
nada quebrou, e o arquivo resultante estava *internamente correto* — só que de
duas gerações atrás. O comparador então reprovou 85 linhas contra dado
perfeitamente válido, e as linhas apontavam para o esticamento:

```
gradient  B  params.target   0,085  vs  0,25
gradient  B  saida.median    21,10  vs  64,00
```

Alguém lendo isso procura o bug no esticamento. Ele não está lá, e não está em
lugar nenhum — o que está errado é *qual* arquivo está no disco.

Mesma família do `records[0]` e da fórmula do `k` duplicada: **sem erro, sem
aviso, e o sintoma apontando para o lugar errado.** O que as três têm em comum é
que a coisa quebrada e a coisa que reclama são objetos diferentes, então o
rastro leva ao segundo.

**O que denuncia:** um artefato cujo conteúdo é coerente mas cuja *proveniência*
não bate. Foi assim que este apareceu — o campo `geradoPor` dizia `chain.py` e
devia dizer `reference_m23.py + reference_bg.py`, e `proposito` falava do passo 8
do Módulo 1 num arquivo que devia falar do Módulo 4. **Um artefato que carrega
quem o gerou se denuncia; um que só carrega números, não.**

## Classe: ler o código do outro acha o que comparar número não acha

Duas vezes nesta sessão, e as duas vezes o defeito era da outra ponta e estava
fora do alcance de qualquer comparação numérica:

| achado | por que número não pegaria |
|---|---|
| três diferenças de **definição** na referência do Módulo 4 (norma vs componentes, ordem do estouro, piso de 0,03) | a divergência sai com tamanho arbitrário e sem causa legível; e uma delas — a ordem do estouro — nem aparece, porque o caminho não é exercitado |
| `chain.py` gravando o JSON no nível do módulo | o arquivo gerado é *correto*; nenhum número denuncia que ele é de outra geração |

**A técnica:** quando a outra ponta entrega código junto com dados, ler o código
é mais barato que comparar os dados — e acha uma classe de defeito que os dados
não contêm. Comparar número responde *"os dois concordam?"*. Ler o código
responde *"os dois estão medindo a mesma coisa?"*, que é a pergunta anterior e
que, quando a resposta é não, invalida a primeira.

Custo medido: uma leitura contra as três rodadas que teriam sido gastas
procurando erro de precisão onde não havia nenhum.

Não substitui a comparação — **as duas verificam coisas diferentes**, e foi a
comparação que fechou as 426 linhas. A ordem é que importa: ler primeiro, porque
a leitura decide se a comparação significa alguma coisa.

## Classe: cota lida no eixo errado reprova implementação correta

Terceira instância nesta sessão, e é o que a torna classe.

| grandeza | o eixo errado | a cota certa | fator |
|---|---|---|---|
| ganhos estelares | eixo [0,1] | tolerância das entradas propagada por `d(a/b)/(a/b) = da/a + db/b` | 36× |
| `mask.luminanceSpan` | eixo [0,1], 4 bins | `3(q3−q1)` ⇒ `3(Δq3+Δq1)` = 24 bins | 6× |
| `saturationByLuminance.after` | só a troca de conjunto | mais `s'·Δk/k`, de `ds'/s' = (Δk/k)(Y/max')` | — |

O padrão: **a grandeza comparada é derivada, e herda a incerteza das entradas
multiplicada pelo Jacobiano da derivação.** Aplicar a ela a tolerância do eixo
onde ela por acaso mora reprova implementação correta — e, o que é pior, convida
a alargar a tolerância até caber, o que esconde divergência de verdade junto.

**O teste para saber se a cota é derivada ou escolhida:** escreva a derivação. Se
ela sai em duas linhas de álgebra a partir da definição, é cota. Se sai de olhar
o número medido e arredondar para cima, é ajuste com outro nome.

Um corolário que custou uma linha: no terceiro caso, o termo do `Δk` **sozinho**
explicava três das quatro divergências. Sem ele, as três teriam sido creditadas à
troca de conjunto — causa errada, e a cota que sairia disso mediria outra coisa.
Uma cota que passa pelo motivo errado é tão ruim quanto uma que reprova.

## Densidade calculada invertendo a cota prova o caminho, não o número

Quando o ramo novo do comparador não tinha dados, ensaiei com curvas de densidade
**calculadas de trás para frente** — invertendo a cota a partir da divergência
medida, para achar o mínimo que a faria fechar.

Isso prova que o caminho roda e dimensiona o pedido à outra ponta. **Não prova
que os números concordam**, e a diferença é grande: a faixa `[0,10]` fechava com
3% de folga contra a curva inventada. Com a curva real ela fechou com **4,8×**.

Dito antes de saber o resultado, e é essa a parte que vale: **um ensaio cujo
resultado é construído para passar precisa dizer isso em voz alta no momento em
que passa**, não depois. Se a curva real tivesse dado menos que o mínimo, aqueles
3% seriam achado e não folga — e quem lesse "fechou no ensaio" sem a ressalva
teria concluído o contrário.


## Um número entregue e não usado é pior que um faltando

Corolário da mesma família, e ele mordeu nesta rodada.

A outra ponta acrescentou o ponto **6,8e-5** à tabela de densidades — exatamente
o Δ que este lado calcula — para que a cota saísse de leitura direta em vez de
interpolação. Boa ideia, entregue, e **não usada**: o Δ medido é `db + dsigma` =
**6,83e-5**, um fio acima do ponto tabelado, e o leitor de curva sobe para o
ponto seguinte porque nunca extrapola uma cota para baixo. A cota aplicada foi a
de 1e-4 — **2.679 pixels contra os 1.826 que o ponto novo daria**, 47% mais
frouxa.

Nenhum veredito mudou (38 bins contra 270 de cota), e é justamente por isso que
valia dizer. **Quem entregou o número acha que está coberto.** Ele calculou a
folga contra 1.826; a folga real foi contra 2.679. Se um dia a divergência
crescer até algo entre os dois, os dois lados discordam sobre se deveria passar,
e ninguém sabe por quê — porque a discrepância está numa leitura de tabela que
nunca apareceu em lugar nenhum.

**A regra:** quando a outra ponta entrega algo sob medida para o seu uso,
**verifique que foi usado e diga qual valor entrou de verdade** — não que o
resultado passou. Um campo ignorado em silêncio é indistinguível de um campo
ausente na saída, e pior na cabeça de quem o mandou.

É o mesmo formato da ressalva do ensaio com densidade invertida: *dizer no
momento em que passa*. Um número que não muda veredito é o mais fácil de não
mencionar, e o mais caro de descobrir depois.

## Recuperar parâmetros de um artefato: medir, não adivinhar

O `docs/before-after.png` precisava ser refeito com a saída nova, e o script que
o gera trazia três constantes de aparência — fonte, tamanho, cor do rótulo —
escritas de memória. **Todas as três estavam erradas**, e as três foram
recuperadas medindo a imagem antiga. Vale registrar o *método*, porque ele se
repete sempre que um artefato precede o script que deveria tê-lo gerado.

### A família da fonte: posição de início de palavra, não largura total

Largura total é uma medida só, e ela não discrimina: Segoe UI 16px dá 287 px,
Arial 16px dá 282, Tahoma 16px dá 294. Todas "batem" com os 284 do original
dentro de 4%, e escolher entre elas por esse número é escolher pelo ruído.

**As posições onde cada palavra começa são impressão digital das larguras de
avanço** — sete medidas ao longo de 284 px em vez de uma:

| | posições de início |
|---|---|
| original | 31, 70, 96, 113, 133, 196, 240 |
| **Segoe UI 16px** | **30, 71, 97, 113, 134, 198, 242** |
| Verdana 14px | 20, 33, 41, 49, 62, 75, … |
| Arial 16px | 19, 32, 40, 49, 62, 74, … |

Seis das sete dentro de 2 px para Segoe; as outras duas erram **desde a
primeira**. O que era empate vira decisão.

**A generalização:** quando várias hipóteses batem num agregado, procure a
medida que tem *estrutura interna* — uma sequência, um perfil, uma distribuição
— em vez de um escalar. Um agregado tem uma chance em N de coincidir; uma
sequência de sete, uma em N⁷.

### A cor: um pixel atingindo os três canais decide

O script dizia `(168, 176, 190)`. Medido, **nenhum canal da imagem antiga passa
de 139/151/168 em lugar nenhum da faixa do rótulo**, e existe um pixel que
atinge os três ao mesmo tempo.

O argumento que fecha: texto de 13–16 px é antialiasado, então a cor observada é
`bg + a·(fill − bg)` com `a ∈ [0,1]` a cobertura do pixel. Se o preenchimento
fosse `(168,176,190)`, o pixel mais claro daria

```
a_R = (139−11)/157 = 0,815
a_G = (151−14)/162 = 0,846
a_B = (168−19)/171 = 0,871
```

— **três coberturas diferentes para o mesmo pixel**, o que só acontece com
antialiasing subpixel, e aí o máximo por canal não coincidiria num único pixel.
Com preenchimento `(139,151,168)` sai `a = 1` nos três, que é um pixel de
cobertura total: consistente, e a explicação mais simples que cabe nos dados.

**A generalização:** um máximo observado é teto de instrumento *ou* valor real, e
o que separa os dois é a **consistência entre canais**. Um teto de antialiasing
deixa assinatura; cobertura total não deixa nenhuma.

### O resíduo que não se persegue

Rasterizado por GDI+ o rótulo sai **3 px mais largo** (287 contra 284) e **2 px
mais alto** (16 contra 14) que o original, feito por FreeType. A cor bate exata.

Não vale perseguir, e a razão é que **o teste da imagem não é o rótulo**: são as
três medidas que os dois scripts imprimem — 1414×555, mediana 4 no painel
esquerdo, 21 no direito, fundo (11,14,19). Elas saem da imagem gerada e não das
constantes, e é isso que impede os dois geradores de divergirem.

Perseguir os 3 px significaria ajustar tamanho ou hinting até a largura fechar,
o que **piora** a identificação: o 16 px foi determinado pelas sete posições de
palavra, e mexer nele para consertar um agregado desfaz a medida que decidiu a
questão. Mesmo formato da tolerância alargada até caber — o número fecha e a
evidência some.

**A regra:** decida antes de medir qual é o critério de "certo", e escreva-o no
verificador. Sem isso, qualquer resíduo vira convite para ajustar até sumir.

## Classe: a premissa de uma afirmação tem que ser medida, não assumida

A cópia em meia escala diz, no log: *"quatro pixels independentes viram um,
então o ruído cai por 2"*. A frase tem duas metades e **só a segunda é
aritmética**. A primeira — que os quatro pixels são independentes — é uma
afirmação sobre o quadro, e num quadro debayerizado ela é **falsa**: o demosaico
reconstrói dois de cada três valores de cor por pixel a partir dos vizinhos.

Medido nos nove fixtures, a razão de ruído em execução:

```
oito fixtures     1,93 a 2,05     dentro da faixa
fixture-seestar   1,29            FORA
```

O `seestar` é o único mosaico CFA da suíte. A faixa disparou na primeira rodada,
no único quadro onde a física diz que deveria.

### A tentação, e por que ela é o defeito

A frase que eu ia gravar no log era *"a redução não está se comportando como
média de caixa exata"*. **Falsa.** A média é exata — quatro termos e uma divisão,
e isso não tem como estar errado. O que falha é a premissa.

É a classe que este projeto mais registra: **a coisa quebrada e a coisa que
reclama são objetos diferentes, e o rastro leva ao segundo.** Se eu tivesse
gravado aquela frase, quem lesse iria auditar o filtro — onde não há nada.

### O conserto: medir a premissa

`whiteness` = σ(lag 1) / σ(lag L) no pior L ∈ {2, 3, 4}. Vale 1,0 para ruído
branco; abaixo disso os vizinhos compartilham ruído e o lag 1 lê menos do que há.

| | 0,753 | 0,955–1,000 |
|---|---|---|
| quem | `seestar` | os outros oito |
| razão | 1,29 | 1,93–2,05 |

**Os lags vêm do bloco, não dos dados.** A redução tem bloco 2×2, então a
independência tem que valer sobre ele e sobre o vizinho imediato: L = 2, 3, 4.
Escolher o lag que mostra o efeito num fixture seria ajustar o diagnóstico à
resposta que já se conhece — e o número sairia impressionante e não significaria
nada.

**A prova de que a medida é a certa:** o perfil do `seestar` dá σ(lag 3)/σ(lag 1)
= **1,291**, e a razão de ruído medida na redução deu **1,2903**. São duas
medições independentes — uma na autocorrelação do quadro cheio, outra na redução
inteira — e caem no mesmo número. O ruído que a média não consegue cancelar é
exatamente o que o vizinho já compartilhava.

## Limiar derivado que os dados não sustentam: dizer, não inventar

Decidido que o botão não aparece quando a promessa não se sustenta, faltava o
limiar. O caminho pedido era derivá-lo: *a faixa aceita é 1,8–2,2, a razão segue
a brancura, então corte na brancura que produz razão 1,8*.

Tentado com os nove fixtures. **A relação não suporta o ajuste:**

| ajuste | n | r | r² | brancura em razão 1,8 |
|---|---|---|---|---|
| nove fixtures | 9 | 0,979 | 0,957 | **0,920** |
| sem o `seestar` | 8 | 0,262 | 0,069 | **0,628** |

O r² de 0,957 é **ponto de alavanca**: tirar um ponto de nove move o limiar de
0,92 para 0,63. Os outros oito ocupam 0,045 de largura em brancura, e ali o
espalhamento é ruído de medição — r = 0,26 entre si. Pior: o 0,920 cai numa
lacuna de 0,20 de largura **sem nenhuma observação**.

Nove pontos em dois aglomerados não são uma curva. São dois pontos com
testemunhas.

**E o argumento é a alavanca, não o r².** Um r² de 0,957 sobre nove pontos
parece decisivo e não é: o que decide é *onde os pontos estão*. Dois aglomerados
separados por um vão — oito juntos, um longe — produzem qualquer r² que se
queira, e a reta passa a ser definida pelo ponto solitário. **Guarde a tabela:
ela é o caso concreto que ensina a olhar a distribuição antes do coeficiente.**
As duas perguntas que a desmontam, nesta ordem: *tire o ponto extremo, o que
sobra?* e *o limiar cai onde há observação?*

### E a derivação certa era não precisar da curva

O critério tinha sido definido como *"a brancura que produz razão 1,8"*. Mas **a
razão é medida em todo quadro, antes de o botão aparecer.** Passar pela brancura
substitui a grandeza que o botão promete por um proxy ajustado dela — e perde
informação em troca de nada.

O portão é `ratio >= 1.8`, o mesmo 1,8 da faixa. **Nenhuma constante nova.** A
brancura fica como *explicação* — é o que diz por que a razão caiu — e não como
critério.

**A regra, e ela generaliza:** quando um limiar derivado exige ajustar uma
relação, primeiro pergunte se a grandeza final já está sendo medida. Se estiver,
o intermediário é sempre pior: ele só pode adicionar erro de ajuste a um número
que já se tem.

**A forma operacional, em uma pergunta:** *antes de derivar um limiar por uma
relação, a grandeza final já está medida?* Se está, o proxy só piora — ele não
pode adicionar informação a um número que já se tem, e pode adicionar erro. Se
não está, aí sim vale ajustar, e aí vale também exigir que os dados sustentem o
ajuste.

## Dizer a verdade num texto que ninguém lê não é o mesmo que não prometer

A primeira versão desta etapa oferecia a cópia reduzida sempre e explicava no
log quando o fator não valia. Parecia suficiente — o log é a razão de existir
deste produto, e ele dizia tudo, com a palavra *"independent"* removida da frase
no quadro onde ela não vale.

**Não é suficiente, e o argumento é de produto:** o botão diz *"half-scale"* e a
pessoa clica porque quer menos ruído. Num quadro debayerizado ela recebe 1,29 em
vez de 2,0 — metade do benefício que o botão sugere — e a correção mora num
parágrafo que a maioria não vai ler.

A divisão que ficou:

> **O log explica. O botão não promete.**

Quando a razão medida fica abaixo de 1,8, o botão **não aparece**, e uma frase
toma o lugar dele ali mesmo — nunca silêncio, que é a confusão 10 da lista: um
botão que some sem explicação lê como funcionalidade quebrada, e a pessoa não
tem como saber que o que aconteceu foi a ferramenta se recusando a prometer.

E isto **mede o quadro, não o formato**. Não é exceção por nome: um FITS já
demosaicado por outro programa chega como três planos, sem `BAYERPAT`, e dispara
igual — porque o que se mede é a correlação entre vizinhos e não o cabeçalho.

## Classe: salvaguarda vazia por construção ≠ salvaguarda sem caso ainda

**As duas se parecem na saída — nenhuma dispara — e a diferença decide se são
dívida ou trabalho fechado.**

| | o estado existe? | o que falta | veredito |
|---|---|---|---|
| **sem caso ainda** | sim | um fixture que o produza | **dívida**: alguém tem que escrever o caso |
| **vazia por construção** | não | nada | **fechado**: não reimplementar |

O caso: a §3.1 do Módulo 5a pede *"objeto já ocupando mais que `cropMaxCoverage`
→ não sugere; não há o que recortar"*. Implementada, e depois **removida**.

**Um objeto que cobre mais de ~70% do quadro É o fundo**, pela definição da etapa
que roda antes: o modelo de placa fina ajusta a mancha suave que domina o quadro
e a subtrai. Medido no `fixture-bigobject`, construído de propósito com 72,9% de
cobertura:

```
bigobject   sinal  16.915 px   extenso    115 px   p75 0,1062
oneobject   sinal 571.279 px   extenso 557.356 px  p75 0,2396
```

O objeto **não chega**. Não existe estado da cadeia em que a salvaguarda tenha o
que julgar, e fabricar um exigiria desligar a extração de fundo — testando um
caminho que a ferramenta real nunca percorre. Um fixture assim verificaria uma
ficção.

**Por que remover e não deixar dormindo:** um parâmetro que não governa nada e um
`if` que nunca é verdadeiro **aparentam vigiar algo**. Quem ler o código daqui a
seis meses conta três salvaguardas e confia em três. O record carrega
`coverageGuard` com o número medido e o motivo, no lugar dela — a pergunta foi
feita, medida e respondida, e isso é mais informação do que o `if` dava.

**Por que não apagar a pergunta junto:** tirar a salvaguarda sem registro perderia
o fato de que ela foi considerada. Daqui a seis meses alguém relê a spec, vê o
buraco, e reimplementa. **O registro é o que fecha.**

**A regra:** quando uma salvaguarda não dispara, decida qual das duas ela é
**antes** de escrever um fixture. A pergunta que separa: *o estado que ela
vigia pode ser produzido pela cadeia real, sem desligar nada?* Se não pode, o
trabalho não é um fixture — é uma linha no record e um parágrafo na spec.

## Classe: uma spec que descreve caminho novo tem que nomear o fixture dele

**Se nenhum fixture existente exercita o caminho, o fixture faz parte da spec, e
não do trabalho de implementá-la.**

O caso: a §4 do Módulo 5a lista os fixtures e diz *"o `gradient` tem um objeto só
e sugere"*. Medido, depois de implementar: o maior componente do `gradient` cobre
**8,6%** do quadro, e o maior dos nove fixtures antigos é o `saturation` com
**19,4%** — logo abaixo do piso de 20%.

**Nenhum dos nove chega a sugerir.** O caminho que a spec inteira existe para
descrever não tinha caso nenhum, e só apareceu porque o passo 3 foi rodado contra
todos eles e a coluna `sug=` saiu `não` nove vezes.

O que isso teria custado se não tivesse aparecido: o retângulo, o botão e o
round-trip do passo 5 seriam escritos e entregues **sem que ninguém tivesse visto
uma sugestão acontecer** — a mesma classe da salvaguarda que nunca disparou, com
o agravante de estar no caminho principal e não no de exceção.

Custou um fixture (`fixture-oneobject.fit`, 37,1%) e uma linha no gerador, porque
o gerador do caso de dois objetos já existia. Teria custado o mesmo se estivesse
na spec desde o início — a diferença é que teria sido escrito antes e não
descoberto depois.

**A regra:** ao escrever a spec de um caminho novo, a seção de fixtures nomeia
**qual fixture o exercita** e, se a resposta for "nenhum", esse fixture é item da
spec. *"Os fixtures existentes cobrem o resto"* é uma afirmação sobre números que
ninguém mediu — e neste caso ela estava errada por 0,6 ponto percentual.

## Regra: a frase gerada mudar quando a ferramenta muda é a funcionalidade

A linha "Not applied" ganhou a palavra `cropping` no Módulo 5a. Hesitei, porque
gente já colou aquela frase em público — e a hesitação estava errada.

**A frase só vale como promessa se listar o que a ferramenta SABE fazer e não
fez.** Antes deste módulo, negar recorte seria negar uma capacidade inexistente:
ruído. Depois dele carrega informação — *ela podia ter recortado e não
recortou*. A palavra não foi acrescentada à frase; **a capacidade foi
acrescentada à ferramenta, e a frase acompanhou**, que é o mecanismo do Módulo 0
funcionando.

**A segunda razão é de uso, e é a que eu não tinha visto:** quem vê o retângulo
desenhado na tela e depois lê o log precisa encontrar ali a confirmação de que o
retângulo ficou **na tela e não no arquivo**. Sem a palavra, essa confirmação não
existe em lugar nenhum — nem no log, nem na imagem. A negação é o único lugar
onde "não recortamos" está escrito.

**A regra para as próximas:** uma linha gerada é escrita exatamente para
acompanhar, e mudar não é custo — é o que ela faz. **Uma frase que nunca muda é
decoração.** A pergunta certa ao acrescentar uma capacidade não é *"posso mexer
na frase?"* e sim *"a frase já deveria ter mudado e não mudou?"* — porque essa
segunda é o defeito de verdade.

## O retângulo vai no canvas, nunca nos pixels

A sugestão de recorte é desenhada sobre a imagem na tela. **Ela é desenhada no
contexto do canvas depois do `putImageData`, e não nos buffers** — e a diferença
importa mais do que parece.

O botão de download reconstrói o próprio canvas a partir de `state.full` ou
`state.view.data`, que são os buffers de pixel. O tracejado vive apenas no canvas
de visualização, então **o arquivo salvo nunca o leva junto**.

O motivo não é técnico, é o mesmo do módulo inteiro: **um retângulo que
aparecesse na imagem baixada seria a ferramenta desenhando na foto de alguém.**
Uma sugestão que se imprime no resultado deixou de ser sugestão.

Vale como forma geral: **anotação de interface e dado de saída são coisas
diferentes e moram em lugares diferentes.** Sempre que os dois compartilham um
buffer, é questão de tempo até a anotação vazar para o arquivo — e o vazamento é
silencioso, porque na tela os dois parecem a mesma coisa.

## Ordem de etapa decidida por uma pergunta de produto, não de código

Duas ordens do Módulo 5a saíram de perguntar *"o que a pessoa recebe?"* e não
*"o que é mais fácil?"*:

**1. O recorte roda ANTES da meia escala.** Se o recorte for aplicado, a cópia
reduzida tem que ser do quadro recortado — senão o segundo botão entrega **um
enquadramento que a pessoa acabou de descartar**. Nenhum teste teria pegado isso:
as duas etapas rodam, as duas reportam, e os dois arquivos saem. Só que um deles
sai errado, e errado de um jeito que só aparece olhando.

**2. O bloco do recorte vem antes do da meia escala no log**, pela mesma razão: a
ordem do log segue a ordem em que as coisas acontecem com os pixels. Um log fora
de ordem descreve uma cadeia que não existe.

### E um caso que caiu de graça

O recorte do `fixture-oneobject` sai em **1333 × 999** — os dois lados ímpares.
A meia escala do quadro recortado descarta **linha E coluna ao mesmo tempo**,
fechando num só golden um caminho que antes não tinha caso nenhum e que, nos
fixtures de lado ímpar, só exercitava a coluna.

Anotado porque foi sorte e não projeto: um caso que aparece de graça **não é
cobertura até alguém perceber que ele está ali e escrever que está.** Um golden
que exercita um caminho sem ninguém saber é indistinguível de um que não
exercita.


## O número estava no record e nenhuma comparação o lia

O pior defeito desta rodada não foi achado por comparação: **ele estava contado,
no record, desde sempre.**

`quantise` grava `clamped.nonFinite` — quantos valores chegaram não-finitos e
viraram zero. Os três fixtures de largura ímpar saíam com **3600**, que é 1200
linhas × 3 canais: **uma coluna inteira preta**. E o `compare-golden` dava
**52/52 byte a byte**, porque a captura e o golden tinham o mesmo defeito.

O golden é uma comparação contra si mesmo. Ele pega mudança; não pega erro que já
estava lá quando a foto foi tirada. A referência Python teria pegado — e pegou,
quando finalmente rodou — mas só porque alguém escreveu a comparação do
`clipLow`, que divergia em exatamente 1200.

**A causa:** a interpolação bilinear da grade do fundo lê `[gx+1]`, e quando o
pixel cai exatamente no último nó esse nó não existe. `undefined − número` é
NaN, e `NaN × 0` continua NaN mesmo com o peso zero. Acontece quando `(w−1)` é
múltiplo do divisor da grade — com 1601 e divisor 16, `1600/16 = 100` cai em
cheio. **Largura ímpar não é a causa; é o que tornou o caso alcançável.**

E o conserto teve que ser escrito **duas vezes**, porque a interpolação existe em
duas cópias: `bgSampleGrid` e o laço de correção, que pré-computa `gx` e `tx`
para o quadro inteiro. Consertei a primeira, o NaN continuou, e a segunda estava
intacta — **a classe da fórmula duplicada, de novo, e desta vez em código que eu
não escrevi.**

### O que mudou por causa disso

Uma afirmação nova no `compare-golden`, e ela **não é comparação**: todo record
com `clamped.nonFinite` tem que trazer zero, em todo golden. Não existe caso em
que um valor não-finito na saída seja o resultado certo, então a asserção não
precisa de referência — **e é justamente por não precisar que ela pega um defeito
que a referência também teria.**

**A regra:** um campo que só existe para contar algo que nunca deveria acontecer
precisa de uma asserção, não de uma comparação. Comparar contra o golden só
pergunta *"mudou?"*; a asserção pergunta *"é possível?"*. O `nonFinite` respondia
3600 havia três commits e ninguém tinha feito a segunda pergunta.

## Classe: o golden compara contra si mesmo

**Um golden pega MUDANÇA. Ele não pega erro que já estava lá quando a foto foi
tirada.**

O caso, e ele é o mais caro da sessão: três fixtures saíam com **1.200 pixels
pretos numa coluna inteira** — a última coluna, num quadro de largura ímpar. Os
goldens foram capturados com o defeito, promovidos com o defeito, commitados com
o defeito, e o `compare-golden` dava **52/52 byte a byte**.

A suíte estava verde **sobre** um defeito. Não havia nada de errado com ela: ela
respondia exatamente a pergunta que sabe responder — *"a saída de hoje é igual à
de ontem?"* — e a resposta era sim, porque ontem já estava errada.

O que achou foi **uma segunda implementação divergindo em exatamente 1200**. Não
foi o olho, não foi o golden, não foi revisão de código: foi o número de outra
ponta batendo de frente com o meu.

**A consequência operacional:** um golden recém-capturado não é evidência de
nada além de reprodutibilidade. Ele vira evidência quando alguma outra coisa —
referência independente, afirmação de invariante, verdade externa nos cards —
diz que os números que ele congelou estavam certos **no momento em que foram
congelados**. Promover um golden é gravar uma resposta; não é conferi-la.

## Classe: afirmação sobre o impossível pega o que comparação nenhuma pega

Corolário do anterior, e é a saída barata.

`quantise` já contava `clamped.nonFinite` — quantos valores chegaram não-finitos
e viraram zero. O campo dizia **3600** havia três commits. Ninguém tinha feito a
pergunta, porque toda comparação da suíte pergunta *"os dois lados concordam?"* e
os dois lados concordavam.

| pergunta | mecanismo | o que escapa |
|---|---|---|
| *mudou?* | golden contra golden | o que já estava errado na captura |
| *os dois concordam?* | contra uma segunda implementação | o defeito que as duas têm |
| ***é possível?*** | **afirmação, sem referência** | **nada desta classe** |

Um valor não-finito na saída **nunca** é o resultado certo. Não existe caso em
que aquele número deva ser diferente de zero — então ele não precisa de
referência para ser julgado, **e é por não precisar que ele pega um defeito que a
referência também poderia ter**.

Hoje a afirmação existe dos dois lados: aqui sobre todo record de todo golden, e
na referência como `naoFinitos.total` da varredura dela. As duas juntas são o que
fecha o caso do NaN que estivesse presente em ambas.

**A regra:** todo campo que existe para contar algo que **nunca deveria
acontecer** merece uma afirmação, não uma comparação. Se o número certo é sempre
o mesmo, comparar é desperdiçar a única verificação que não depende de ninguém
estar certo.

## Item de revisão: ao consertar uma fórmula, procure a segunda cópia ANTES de recapturar

**Terceira vez nesta sessão**, e a terceira em código cada vez mais alheio:

| | onde | como apareceu |
|---|---|---|
| 1 | pré-passada do ruído de croma duplicava o `k` | o controle negativo pegou: a cópia intacta aprovou a máscara quebrada |
| 2 | `records[0]` contra busca por id | uma etapa inserida à frente entregou a medição errada |
| 3 | bilinear da grade do fundo, **duas cópias** | consertei `bgSampleGrid`, recapturei, o NaN continuou |

A terceira é a que vira regra, porque o custo foi um ciclo inteiro de captura —
oito minutos de navegador — para descobrir que o conserto tinha ido para metade
do problema. E era código que eu não tinha escrito, então "eu lembraria" não
valia.

**A regra, em uma linha:** *ao consertar qualquer fórmula, procure a segunda
cópia antes de recapturar.* Grep pelo trecho característico — no caso,
`[gx + 1]` e `+ gw` — e conte. Se o grep der mais de um, conserte os dois na
mesma edição ou junte-os numa função antes de tocar em qualquer coisa.

E a pergunta que vem junto, porque foi ela que deixou a duplicação existir: a
segunda cópia do fundo existe **por desempenho** — `gx` e `tx` dependem só de x
e são pré-computados para o quadro inteiro em vez de por pixel por canal. É uma
razão boa. **Uma duplicação com razão boa continua sendo duplicação**, e o que
falta nela é a anotação que diz onde está a irmã.

## Classe: entregar um número pedido sem verificar que ele fecha

**É a mesma doença de entregar um número que ninguém lê** — e é pior, porque o
outro lado para de procurar.

O caso: sobrou um FAIL com a causa nomeada, e o que faltava para fechá-lo era o
span da distribuição de `|d|`. Pedido, e entregue — **com a verificação junto**:

```
diferença observada    6,155e-5
cota 8*span/65535      3,461e-5      1,78x a cota
termo da mediana       2,98e-8       não salva
```

**O span não fecha.** Se ele tivesse chegado sem essa conta, eu teria escrito a
linha do comparador, recapturado, visto o FAIL continuar e gasto uma rodada
procurando erro na minha aritmética — quando a hipótese inteira estava errada.

O número entregue com a conta junto **descartou duas hipóteses** (quantização do
estimador e incerteza da mediana) e deixou o achado de pé, que é mais do que o
número sozinho teria feito.

**A regra:** quando alguém pede um número para fechar um buraco, meça se ele
fecha **antes de mandar**, e mande a conta junto. Um número que não fecha,
entregue em silêncio, transfere a investigação para quem vai confiar nele.

É simétrico ao "Um número entregue e não usado é pior que um faltando", acima: lá o remetente achava que estava
coberto; aqui o destinatário acharia. As duas se consertam com a mesma frase —
**diga qual valor entrou e o que ele fez.**

## Em aberto


**Módulo 5a: os sete passos fechados, com UM FAIL nomeado.**

A meia escala e o recorte sugerido estão na cadeia, no log, no registry e na
referência Python. `compare-reference` dá **865 comparações, 1 FAIL**.

O que ficou aberto, em ordem de peso:

**1. `nonlinear | meiaEscala | ruido.antes` — 4,04 de 4,00 bins, 1% acima.**

Achado, não tolerância. Três hipóteses medidas e descartadas:

| hipótese | medição | veredito |
|---|---|---|
| o histograma deste lado | mediana do `analysePlane` contra exata no MESMO array: **−0,53 bin** | descartada |
| quantização do estimador | cota `8·span/65535` = 3,461e-5 contra 6,155e-5 observados — **1,78×** | descartada |
| incerteza da mediana | `skyMedian` difere em **2,98e-8**; o termo não acrescenta nada | descartada |

O que se sabe: a diferença é dos **quadros**, e o `nonlinear` é o ramo
não-linear, onde o alvo sai da própria mediana do quadro e uma diferença pequena
na entrada é amplificada pela transferência — a mesma amplificação já registrada
no `colour`, onde 1,9e-6 na mediana virou 2,4e-4 em `midtones`.

E a pista que ainda não foi seguida: das doze, o `nonlinear` tem o **maior span**
da distribuição de `|d|` — **0,2835 contra 0,028 a 0,098** em todas as outras.
Três a dez vezes mais larga.

**A próxima medição não é quantos pixels do céu diferem, é QUAIS.** Se o conjunto
for o mesmo e o sigma divergir mesmo assim, a causa é a **forma** da distribuição;
se o conjunto diferir na cauda, é **seleção**. As duas pedem consertos diferentes
e nenhuma das duas foi eliminada.

**2. Cota parcial em `components` e `extenso.pixels`.** A curva de
`extendedPixels` no limiar de ocupação chegou e está em uso, mas a cota ainda não
cobre as duas fronteiras ao mesmo tempo — a do sinal e a da ocupação — e a linha
diz isso. Fecha somando as duas densidades, como foi feito no `amountCheio` do
Módulo 4.

**3. A salvaguarda `cropMaxCoverage` continua vazia por construção**, e isso está
fechado e não é dívida — ver a classe acima. Registrado aqui só para que a lista
de salvaguardas do Módulo 5a não pareça ter três quando tem duas.

**4. Sem desfazer no recorte aplicado.** A pessoa reabre o arquivo. Deliberado
por enquanto: um "desfazer" que reconstruísse estado a partir da tela seria o
começo de uma segunda fonte de verdade.

**Saturação seletiva: LIGADA desde a v1.3.0.** `saturation: true` em `run.js`.
Os nove passos da §6 do Módulo 4 estão fechados, e o nono — a segunda
implementação — é o que autorizou ligar: até ele, a etapa estava verificada
contra si mesma (goldens, controles negativos, teoremas) e não contra código que
não é este. O que a autoriza, em ordem de peso:

1. **Matiz contra os cards do fixture**: núcleo 0,0832 e nebulosa 0,9929,
   idênticos antes e depois da etapa, batendo com o ângulo que o gerador
   escreveu. **Verdade externa** — a única verificação desta etapa que não saiu
   de nenhuma das duas implementações.
2. **426 comparações contra `reference_m23.py`, 0 FAIL**, incluindo as quatro
   cotas derivadas de curva de densidade e as duas cotas propagadas.
3. **A salvaguarda de ruído de croma com controle permanente que a vê recusar**
   (`compare-safeguards`), e não apenas prometer.

O que a etapa faz, medido no `fixture-colour` (saturação HSV média por faixa de
luminância, antes → depois):

| faixa | pixels | antes | depois | |
|---|---|---|---|---|
| 0,00–0,10 | 1.115.630 | 0,3698 | 0,3698 | **intocado** — abaixo do limiar de SNR |
| 0,10–0,20 | 155.980 | 0,2803 | 0,2807 | +0,1% |
| 0,20–0,35 | 89.688 | 0,1646 | 0,1737 | +5,5% |
| 0,35–0,55 | 77.248 | 0,0781 | 0,0919 | +17,6% |
| 0,55–0,80 | 368.714 | 0,2801 | 0,3667 | +30,9% |
| 0,80–1,01 | 112.740 | 0,0646 | 0,0821 | **+27,1%** — a queda nas altas luzes |

A última linha é a única que importa discutir: ela sobe **menos** que a anterior,
e é a queda nas altas luzes funcionando. Sem ela um núcleo brilhante vira disco
chapado de cor.

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
