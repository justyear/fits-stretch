# Investigação: a normalização de FITS float

**Status: investigação. Nada implementado, e a decisão não está tomada.**

**Origem:** revisão cruzada. Os quatro ramos de `normalisePhysical`:

```js
bitpix > 0    -> faixa do contêiner, [BZERO + BSCALE*min, BZERO + BSCALE*max]
mx <= 1.5     -> já está em [0,1], divisor 1
mx <= 70000   -> divisor 65535 ("float numa escala de 16 bits")
senão         -> divisor = mx, o MAIOR PIXEL DO QUADRO
```

A objeção: o último faz **um pixel definir a escala do quadro inteiro**, e dois
empilhamentos do mesmo alvo podem normalizar diferente.

**Onde ela está hoje:** a escala, sozinha, é quase inofensiva — o perigo é o
**acoplamento entre a escala e limiares absolutos a montante**. E o primeiro
arquivo real medido (§1) mostrou que a convenção que falta **está no header**,
escrita por quem gravou, o que abre uma quarta saída (§3.D) que não adivinha.

---

## 0. O tamanho do problema, medido

> *"Se a cadeia inteira for invariante a escala multiplicativa, o ramo `/max` é
> feio mas inofensivo. Se não for, é grave."*

**Instrumento:** o arquivo é lido uma vez, os float32 big-endian são
multiplicados por *k* em memória e a cadeia roda sobre um `Blob`. Header
preservado, geometria preservada, ruído preservado: só a escala física muda.
Nenhum fixture novo foi versionado para isto.

### 0.1 Quatro pontos, para enquadrar

No `fixture-gradient`:

| k | ramo | regra linear | mediana | **saída (mediana G, 8 bits)** | pretos |
|---|---|---|---|---|---|
| 1 | `unit` ÷1 | LINEAR | 0,016759 | **22** | 0,11% |
| 2 | `unit` ÷1 | LINEAR | 0,033529 | **22** | 0,11% |
| 3 | `unit` ÷1 | **NÃO-LINEAR** | 0,050294 | **13** | 0,08% |
| 4 | **`float16` ÷65535** | LINEAR | ~0 | **0** | **99,98%** |

> **CORREÇÃO, e ela é o tipo de coisa que este projeto passou semanas recusando.**
>
> A primeira versão desta seção concluía *"tudo que roda depois da MTF é
> invariante a escala"*. **Isso é um fixture, não um teorema** — e a §0.4
> mostra que é falso noutro tipo de imagem. O que foi medido é mais estreito:
>
> > No `fixture-gradient`, sob as escalas testadas, a saída pós-esticamento não
> > mudou **enquanto o ramo de normalização e a regra linear se mantiveram**.
>
> Generalizar de um fixture para "a cadeia" é exatamente a classe da §2 do
> Módulo 5a, com outro conteúdo. Registrada no `NOTAS`.

### 0.2 O `/max` e a estrela quente

Mesmo quadro ×200000 (máximo 94.269), e uma cópia idêntica **com um único pixel
em 3× o máximo**:

| | divisor | mediana | estrelas | rejeitadas por saturação | ganho R | **saída** |
|---|---|---|---|---|---|---|
| sem o pixel quente | 94.269 | 0,035569 | 14.974 | 40 | 1,013773 | **22** |
| **com um pixel 3×** | **282.807** | **0,011856** | 15.015 | **0** | 1,012758 | **22** |

**Um pixel triplicou o divisor do quadro inteiro e a imagem não mudou.** Média
25,48 contra 25,53, pretos 0,11% nos dois.

Mas a mediana caiu 3×, e a mediana é a entrada da regra `>= 0,05`. O pixel
quente não estraga a imagem: **move o quadro em relação aos limiares**. Um
quadro com mediana 0,06 seria não-linear; com uma estrela quente a mais, linear.
Mesmo alvo, mesma noite, duas entregas diferentes.

E todo número do log muda junto: `rejeitado.saturado` **40 → 0**, `estrelas`
14.974 → 15.015, `ganho R` na quinta casa.

> **Números que mudam por causa de um pixel descrevem o instrumento, não o céu.**
>
> E num produto cujo argumento é o log, isso não é um detalhe de precisão: é a
> diferença entre uma medição e um artefato de medição, publicada como se fosse
> a primeira.

### 0.3 O par controlado que a suíte ganhou

`fixture-float16` e `fixture-floatmax` são **a mesma cena** em escalas físicas
diferentes (×65535 e ×250000), então a diferença entre os goldens deles é o ramo
e nada mais:

```
shadows    0,0141187625   nos dois
midtones   0,0106797548   nos dois
clipLow    0              nos dois
PNG        difere em 14 bytes de compressao
```

**Dividir por 65535 ou dividir pelo maior pixel dá a mesma imagem — quando o
maior pixel é honesto.** A escolha do divisor, por si, não faz mal. O que faz
mal é ele **mudar** entre dois arquivos do mesmo alvo.

### 0.4 A CURVA, e ela responde o que os quatro pontos não respondiam

`k` de 1,0 a 5,0 em passos de 0,1 — **41 pontos × 3 fixtures = 123 rodadas da
cadeia inteira**. Quatro fotografias não dizem em que ORDEM as decisões trocam,
e a ordem é o diagnóstico.

**A ordem dos degraus, por fixture:**

| | `satRej` sobe | amostras de fundo | regra linear | ramo | **saída move ≥1 nível** |
|---|---|---|---|---|---|
| **gradient** | 1,9 | 3,2 | **3,0** (L→NL) | 3,2 | **3,0** |
| **colour** | 1,1 | 1,5 | *nunca* | **1,6** | **1,6** |
| **nonlinear** | 1,1 | 1,2 | **1,6** (NL→L) | 1,6 | **1,1** |

**A ORDEM DIFERE NOS TRÊS. Depende do conteúdo, e isso é o pior dos dois
resultados possíveis.**

- No `gradient` a regra linear dispara **antes** do ramo (3,0 contra 3,2).
- No `colour` a regra linear **nunca** dispara: o penhasco do ramo chega primeiro.
- No `nonlinear` a regra dispara **ao contrário** (NL→L), junto com o ramo.

**E a margem de exposição antes de a imagem mudar vai de 10% a 200%:**

```
nonlinear   a saida move em k=1,1     10% de exposicao
colour      a saida move em k=1,6     60%
gradient    a saida move em k=3,0    200%
```

**Por que a fronteira do ramo cai em k diferente:** ela lê o **máximo**, e o
máximo é uma estrela. `1,5 / max` dá 3,2 no gradient (max 0,471) e 1,6 no colour
e no nonlinear (máximos 1,0 e 1,0). **A posição do penhasco é escolhida por um
punhado de pixels.**

**E a invariância não vale noutro tipo de imagem.** O `nonlinear` já está no ramo
não-linear, onde o ponto preto sai de um percentil e a mediana é **mantida onde
está** — o que é o comportamento certo para dado já esticado e é, por definição,
dependente do nível absoluto:

```
k      mediana      shadows      saida
1,0    0,24672      0,23856       63
1,1    0,27139      0,26246       69
1,5    0,37008      0,35818       94
```

**Nenhum limiar foi cruzado entre 1,0 e 1,5** e a saída se move de 63 para 94.
A invariância do §0.1 é uma propriedade do **ramo linear**, não da cadeia.

### 0.5 Veredito

**Nem "feio mas inofensivo", nem "toda imagem errada".** É **troca de ramo
latente**, com três agravantes medidos:

1. a falha é **discreta** — nada, nada, e então 99,98% preto;
2. a posição do penhasco é fixada por **um punhado de pixels**;
3. a ordem em que as decisões trocam **depende do conteúdo**, então não existe um
   "fator seguro" único para declarar ao usuário.

O conserto não é adivinhar melhor a escala. É **tirar a dependência**.

---

## 1. O que existe de fato como convenção — PRIMEIRO ARQUIVO REAL MEDIDO

**n = 1, e ele derruba a §2 como estava escrita.** Um empilhador de telescópio
inteligente, saída de Siril, float32, trazido por um parceiro de teste:

```
BITPIX    -32
BZERO     0.0        BSCALE  1.0
DATAMIN   AUSENTE
DATAMAX   AUSENTE
BUNIT     AUSENTE
ROWORDER  BOTTOM-UP

min 0,000000000   max 1,000000000   mediana 0,001177378
p99,9 0,034454248                   max/p99,9 = 29,02
```

**AS TRÊS CHAVES QUE A §2 CHAMAVA DE DECISIVAS NÃO EXISTEM.** `DATAMIN`,
`DATAMAX` e `BUNIT`, as únicas evidências do padrão FITS que podiam legitimar um
divisor, estão ausentes — **no caso mais comum do público-alvo.**

Uma decisão apoiada nelas não decide nada onde importa. Ela seria correta e
inútil, que é um jeito particularmente caro de errar: passaria em revisão,
passaria na suíte, e cairia no ramo do palpite exatamente nos arquivos que as
pessoas trazem.

### 1.1 O que o arquivo real trouxe no lugar

```
PROGRAM  = 'Siril 1.4.4'
CREATOR  = 'ZWO Seestar S30 Pro'
PRODUCER = 'ZWO'

HISTORY  "additive+scaling normalized input, normalized output"
```

**A convenção está no header — escrita por quem gravou, em palavras.** Não são
chaves do padrão FITS: são a assinatura do escritor e o registro do que ele fez.
E o `HISTORY` **declara a normalização explicitamente**.

Isso abre uma saída que a §2.2 tinha dado por fechada, e a §3.D a avalia.

### 1.2 Dois números deste arquivo que valem por si

**`max/p99,9 = 29,02`.** O fixture mais extremo da suíte dá **5,18**. O arquivo
real é **5,6× mais extremo que o pior caso sintético** — um pixel a 29× o
percentil 99,9, decidindo a escala do quadro inteiro se ele caísse no ramo
`/max`. A medição da §2.1, feita só em fixtures, **subestimava a fragilidade**.

> É a lição da representatividade outra vez, e agora do outro lado: os fixtures
> não mentiram sobre o comportamento, mentiram sobre a **magnitude**. Uma
> propriedade medida só em dado sintético pode estar certa em forma e errada em
> escala, e "errada em escala" é o bastante quando o número decide um limiar.

**`max = 1,000000000` exato.** A saída normalizada do Siril fixa o máximo em 1,0
por construção. Então **toda a população do caso principal senta no mesmo ponto**,
e a distância dela até o penhasco (`mx > 1,5`) é **50% de exposição** — uma
margem que não veio de medição nenhuma, e sim da constante 1,5 ter sido escolhida
como "um pouco acima de 1". Funciona. Mas funciona por uma folga que ninguém
derivou, sobre uma população que está toda no mesmo lugar.

### 1.3 O resto da tabela continua sem medição

| escritor | o que se acredita | confiança |
|---|---|---|
| **Siril** | float32 em [0,1], e **declara isso no `HISTORY`** | **MEDIDO, n=1** |
| **Seestar (S30/S50)** | subs em inteiro de 16 bits, `BZERO = 32768` | **alta** — o `fixture-seestar` reproduz; e o arquivo real mostra que o stack passa pelo Siril e sai float |
| **PixInsight** | internamente [0,1]; ao exportar FITS de 32 bits pode gravar em [0,1] **ou** na faixa do contêiner | **média** — há uma opção, e opção é coisa que se erra |
| **astropy** | grava o array como está: **sem convenção e sem assinatura** | **alta** — é biblioteca, não aplicativo |
| **fpack / funpack** | preserva `BITPIX`; para float quantiza por padrão | **média-alta** |

A linha do **astropy** é a que interessa para a §3: é o escritor que
provavelmente **não** assina, e é por isso que a quarta saída precisa de um caso
residual em vez de substituir as outras.
população.

---

## 2. O que dá para inferir COM SEGURANÇA do header

| evidência | o que decide | força |
|---|---|---|
| **`BITPIX > 0`** | a escala é a do contêiner — e é o que o código já faz | **decide sozinho** |
| **`BSCALE` / `BZERO`** | a transformação física; ≠ (1,0) é declaração explícita | **decide sozinho quando presente** |
| **`DATAMAX` / `DATAMIN`** | a faixa **declarada pelo escritor** | **forte quando presente** — é o que falta hoje |
| **`BUNIT`** | unidade física; presente ⇒ os valores **não** são [0,1] | **indiciária** |
| **`HISTORY`** | identifica o escritor, e o escritor implica a convenção | **forte, indireta** |
| **o maior pixel** | **nada** | **não decide** |

`DATAMAX` e o maior pixel podem ter o mesmo valor e **não são a mesma
afirmação**: um é o escritor dizendo *"a faixa é esta"*, o outro é o quadro
dizendo *"o pixel mais brilhante é este"*. Hoje o código usa o segundo como se
fosse o primeiro.

### 2.1 A grandeza frágil e a robusta, medidas

`mx <= 1.5` decide pelo **máximo**. Medido nos quatorze fixtures legíveis por
este instrumento — máximo contra o percentil 99,9:

```
fixture       max        p99,9      mediana      max/p99,9
seestar       20650       3984         717         5,18x
nobayer       20650       3984         717         5,18x
gradient      0,4713      0,1344      0,01671      3,51x
oneobject     0,4054      0,1515      0,01273      2,68x
twoobjects    0,4045      0,1600      0,01386      2,53x
bigobject     0,4078      0,1717      0,04473      2,38x
float16       65535       34367       987,6        1,91x
floatmax      250000      131102      3767         1,91x
edge          1,0000      0,6545      0,01565      1,53x
flatsky       0,02346     0,01837     0,01100      1,28x
saturation    0,9175      0,7512      0,01540      1,22x
nonlinear     1,0000      0,9581      0,2463       1,04x
colour        1,0000      1,0000      0,01689      1,00x
```

**O máximo chega a 5,18× o percentil 99,9.** Ele mora numa população de poucos
pixels, e a §0.2 mediu o que acontece quando um deles se move: divisor 3× maior,
todos os números do log diferentes.

**A mediana e o MADN não se movem com um pixel.** Estão medidos, estão no
record, e já governam tudo que é robusto na cadeia — a rejeição de amostras de
fundo, o piso da seleção estelar, o `shadows` do esticamento.

### 2.2 E o achado: nenhuma grandeza robusta separa os ramos

Trocar `mx` por `p99,9` **não estabiliza o ramo sob escala** — só move a
fronteira:

```
              fronteira em k
              com mx        com p99,9
gradient       3,2           11,2
colour         1,6            1,5
nonlinear      1,6            1,57
```

E não é uma questão de escolher outro percentil. **Nenhuma estatística calculada
sobre os valores pode fazer isso, e o motivo é definicional:**

> Dois arquivos com **os mesmos valores de pixel** têm que receber o mesmo ramo.
> Uma imagem escrita em [0,1] e exposta 3× mais brilhante, e uma imagem escrita
> numa escala de 16 bits que está muito fraca, **são os mesmos números**.

O ramo tenta ler uma **convenção** a partir de **valores**, e a convenção não
está nos valores. Uma grandeza robusta conserta a fragilidade a um pixel — que é
real e vale por si — e **não pode** consertar a ambiguidade, porque a
ambiguidade não é ruído: é informação ausente.

**Consequência de desenho, e ela decide a §3:** a informação que falta está no
**header** ou não está em lugar nenhum.

> **E eu fechei uma porta a mais do que a medição fechava.** A frase acima estava
> certa e a conclusão que tirei dela era estreita demais: *"quando não está, a
> resposta honesta é declarar ou recusar"* tratou `DATAMAX`/`BUNIT` como se
> fossem todo o header. O arquivo real da §1 não tem nenhuma das duas — e tem
> `PROGRAM`, `CREATOR` e um `HISTORY` que **declara a normalização em palavras**.
>
> O que a §2.2 prova é que **nenhuma estatística** resolve. Ela não prova nada
> sobre o header, porque eu só tinha olhado para três chaves dele. A quarta saída
> está na §3.D, e ela é a que cobre o caso principal.

### 2.3 A fronteira de responsabilidade que `normalisePhysical` não tem

A função junta duas coisas que não são a mesma:

```
valor armazenado -> valor fisico      BSCALE/BZERO -- PADRAO FITS
valor fisico     -> [0,1] de trabalho  divisor      -- ESCOLHA DA FERRAMENTA
```

**A primeira é leitura. A segunda é decisão.** A primeira tem uma resposta certa
definida por um padrão de 1981 e não admite opinião; a segunda é uma política do
produto, e é onde mora tudo que esta investigação encontrou.

Estarem na mesma função é o que permite um divisor escolhido pelo máximo
**contaminar o que deveria ser só leitura**: hoje `rawMin`/`rawMax` — que são
leitura pura, exatos, e o comparador já os trata com cota zero — saem da mesma
passada que escolhe o divisor, e o record não separa *"isto é o que o arquivo
diz"* de *"isto é o que eu decidi"*.

**O que cada metade pode e não pode decidir:**

| | pode | não pode |
|---|---|---|
| **leitura** | aplicar `BSCALE`/`BZERO`; reportar min, max, mediana **nas unidades do arquivo**; reportar `BUNIT`, `DATAMIN`/`DATAMAX` | escolher divisor; olhar para o conteúdo da imagem para decidir coisa alguma |
| **decisão** | escolher o divisor a partir do que a leitura reportou **e do header**; recusar; declarar a suposição | mudar valor físico; inventar faixa que o escritor não declarou |

**Não refatorar agora.** Fica registrado para que, se o conserto acabar sendo
separar as duas, a razão já esteja escrita — e para que a alternativa (manter
junto) tenha que argumentar contra isto.

---

## 3. As quatro saídas

**A §2.2 fechou a porta ESTATÍSTICA, e só ela.** A frase era *"a convenção não
está nos valores"* — e isso continua verdade. Mas o arquivo real da §1.1 mostra
que a convenção **está no header, escrita por quem gravou**, e essa porta a §2.2
não tinha olhado.

### D. LER O ESCRITOR, NÃO OS VALORES — a quarta, e a que cobre o caso principal

Um arquivo com `PROGRAM = 'Siril 1.4.4'` e `HISTORY` dizendo *"normalized
output"* está em [0,1] **por declaração**, não por inferência. Não é uma
estimativa com erro-padrão: é o escritor dizendo o que fez.

**Por que ela é diferente das outras três:** A, B e C tratam do que fazer quando
não se sabe. **D é sobre reconhecer quando se sabe** — e a §1 mede que, no caso
mais comum, se sabe.

**A máquina já existe nesta base de código.** `STRETCH_HISTORY` em `run.js` é
uma tabela de expressões regulares sobre as linhas de `HISTORY`, e o que ela
produz (`historyHits`) já alimenta a regra linear/não-linear, já vai para o
record e já é impresso no log:

```js
var STRETCH_HISTORY = [
  [/autostretch/i,        'Autostretch'],
  [/histogram\s*transf/i, 'Histogram Transf.'],
  ...
];
```

D é **a mesma forma, para outra pergunta**. Não é mecanismo novo: é a segunda
aplicação de um mecanismo que já passou por revisão, já tem lugar no diag e já
tem precedente de ler uma declaração em vez de inferir de pixel.

#### D.1 A cobertura, medida — e a medida dos fixtures não vale

| população | traz `PROGRAM`/`CREATOR`/`HISTORY` utilizável |
|---|---|
| **fixtures sintéticos** | **13 de 14** — e o número **não é evidência** |
| **arquivos reais** | **1 de 1** — `PROGRAM`, `CREATOR`, `PRODUCER` e `HISTORY` |

> **Os treze fixtures trazem `PROGRAM` porque eu os escrevi assim.** Medir
> cobertura de header numa população que eu mesmo gerei é perguntar à minha
> própria decisão se ela foi tomada. **Zero informação**, e é exatamente a classe
> da §2 do Módulo 5a com outro disfarce — a suíte confirmando o que a suíte
> assumiu.
>
> O único número com valor de evidência aqui é **1 de 1**, e n=1 é n=1.

O `fixture-rice` é o que não traz, e por um motivo que importa para a
implementação: **num `.fz` o HDU primário tem só `SIMPLE/BITPIX/NAXIS/EXTEND`**,
e tudo mora na extensão `BINTABLE`. Uma leitura de escritor tem que olhar o
header da **extensão de imagem**, não o primário — o código já acha esse HDU, mas
a regra tem que dizer qual header ela lê.

#### D.2 A ordem de precedência que D exige

D não substitui as evidências do padrão: **entra abaixo delas e acima de
qualquer estatística.**

```
1. BITPIX > 0                    o conteiner decide       PADRAO
2. BSCALE/BZERO diferentes de (1,0)  declaracao explicita  PADRAO
3. DATAMIN/DATAMAX               faixa declarada           PADRAO
4. PROGRAM/CREATOR + HISTORY     o escritor declarado      <- D
5. estatistica sobre os valores  palpite                   <- hoje, sozinho
```

Hoje a decisão salta de 1–2 direto para 5. **D preenche o degrau que falta, e é
o degrau onde o caso principal mora.**

#### D.3 O caso residual, que é onde A e B passam a valer

Quando **nenhuma** das chaves existe — nem padrão, nem assinatura — aí sim não há
base. É o caso do **astropy**: uma biblioteca grava o array como está e
tipicamente não assina nada.

**E essa é a mudança de desenho que D provoca:** declarar-ou-recusar deixa de ser
a política do caso principal e passa a ser a do **residual**. Um produto que
recusa o arquivo mais comum do seu público é um produto que não funciona; um que
recusa o arquivo sem procedência declarada está fazendo o que promete.

#### D.4 O risco, e o que dele é detectável

**Um header pode mentir, ou envelhecer.** Três formas, e elas não são iguais:

| risco | detectável? |
|---|---|
| o arquivo passou por outro programa que **acrescentou** `HISTORY` | **sim** — `HISTORY` é append-only por convenção, então a última linha é a última operação; ler a ordem, não só a presença |
| o arquivo passou por outro programa que **reescreveu pixels sem registrar** | **NÃO** — e isto tem que ser declarado, não mitigado |
| a declaração **contradiz os dados** | **sim, e é barato** |

A terceira é a que dá uma verificação de graça: uma declaração de *"normalized
output"* é **falsificável**. Se o header diz [0,1] e o máximo é 32.000, a
declaração está errada ou o arquivo mudou depois — e o certo ali não é escolher
um dos dois, é **recusar**, porque as duas únicas fontes de verdade disponíveis
discordam.

```
declaracao consistente com os dados   ->  usa a declaracao
declaracao CONTRADITA pelos dados     ->  RECUSA: as duas fontes discordam
sem declaracao                        ->  caso residual (D.3)
```

**Medido no arquivo real:** `HISTORY` diz *"normalized output"* e o máximo é
**1,000000000 exato**. Consistente. A verificação não custa nada — o máximo já é
calculado — e transforma D de "confiar no header" em **"confiar no header e
conferir contra os pixels"**, que é uma promessa diferente e muito mais forte.

**O que não é detectável fica escrito no log**, pela regra que esta mesma rodada
aplicou ao CFA: declarar a suposição *e* o que acontece se ela estiver errada.
Aqui seria — *a escala veio do que `PROGRAM` declara; se este arquivo passou por
outro programa que mudou os valores sem registrar, a escala pode estar errada e
nada aqui percebe*.

#### D.5 O que D não resolve

- **É um registro de comportamento de terceiro.** Se o Siril mudar de convenção
  numa versão futura, a tabela fica errada em silêncio. Mitigação possível: o log
  imprimir **qual regra casou e qual versão foi lida**, de modo que a entrada
  velha apareça no artefato em vez de só no código.
- **Não cobre escritor sem assinatura**, por construção — é o D.3.
- **Não torna o ramo `/max` correto**; torna-o **raro**, o que é outra coisa. Se
  a §1 crescer e ninguém real cair nele, a saída C volta à mesa.

### As outras três, com o papel que passam a ter

**A. DECLARAR A CONSEQUÊNCIA.** Continua valendo, e agora como **complemento de
D**, não como alternativa: mesmo quando a escala vem de uma declaração, o log tem
que dizer de onde ela veio e o que não é detectável.

**B. RECUSAR.** Continua valendo, e **muda de lugar**: do caso principal para o
residual (D.3) e para a contradição (D.4).

**C. TIRAR O RAMO `/max`.** Continua em aberto e **depende da §1 crescer**. O
arquivo real não cai nele — cai no `unit`, com máximo 1,0 exato.

**Nenhuma das quatro é "adivinhar melhor".** D é a única que **não adivinha**.
---

## 4. O que muda no resto da cadeia se a escala mudar

| etapa | grandeza que decide | invariante? | medido |
|---|---|---|---|
| **decode** | `mx` contra 1,5 e 70000 | **NÃO — é a fronteira** | penhasco em k=1,6 / 3,2 conforme o fixture |
| **regra linear/não-linear** | `mediana >= 0,05` | **NÃO — absoluto em dado linear** | gradient: L→NL em k=3,0; nonlinear: NL→L em k=1,6 |
| **extração de fundo** | mediana + σ·MADN das caixas | **quase** | amostras aceitas mudam em k=1,2 a 3,2 — a rejeição é relativa, mas a contagem se move |
| **seleção estelar (piso)** | `mediana + 12·MADN` | **sim** | — |
| **seleção estelar (teto)** | `ccStarMax = 0,85` | **NÃO — absoluto em dado linear** | `satRej` sobe já em k=1,1 em dois dos três |
| **razões estelares e ganhos** | razão acima do pedestal | **sim** | ganhos batem na 3ª casa em todos os k |
| **esticamento, ramo LINEAR** | `shadows = mediana + σ·MADN`, alvo na saída | **sim** | gradient: saída 22 de k=1 a 2,5 |
| **esticamento, ramo NÃO-LINEAR** | percentil + mediana **mantida** | **NÃO, e é por desenho** | nonlinear: saída 63 → 94 de k=1 a 1,5, sem cruzar limiar nenhum |
| **saturação seletiva** | SNR e joelho, **depois** do esticamento | **sim** | — |
| **recorte sugerido** | `Y > céu + 2,5σ`, **depois** do esticamento | **sim** | recusou em todos os k |
| **quantise** | 8 bits da saída esticada | **sim** | — |

**Três não-invariantes a montante do esticamento, e uma no próprio esticamento.**
A quarta é a que derrubou a generalização do §0.1: o ramo não-linear **não é**
invariante, e está certo que não seja — ele existe para preservar a colocação
tonal que já está no arquivo, e "colocação tonal" é uma afirmação sobre níveis
absolutos.

**A forma do conserto sai daqui:** as grandezas que decidem — `mx`, a mediana do
quadro, o teto de 0,85 — são absolutas num eixo que o próprio decode escolheu.
Enquanto forem, **qualquer divisor é uma escolha com consequência**.

---

## 5. O que esta investigação NÃO fez

- **Não tocou em código de conserto.** As cópias escaladas foram construídas em
  memória, no navegador, e nada foi versionado.
- **Não mediu pixel de terceiro.** O arquivo real entrou como **header e três
  números**, pela regra do `CLAUDE.md`; nenhum pixel dele foi lido aqui e nenhum
  arquivo dele entrou na árvore.
- **Não fechou a §1**: n=1. Um arquivo real mostra que D cobre o caso principal
  e **não mostra qual fração da população traz assinatura**.
- **Não propôs limiar novo.** Trocar 0,05 por outro número escolhido seria
  repetir o defeito com outro valor.
- **Não escreveu a tabela de escritores.** Ela é o coração de D e precisa de mais
  de um arquivo para existir sem inventar entradas.

## 6. Ordem

1. ~~**Fixture para cada ramo de normalização.**~~ **FEITO.** Entraram
   `fixture-float16`, `fixture-floatmax` e `fixture-nobayer`; `compare-golden`
   foi de 52 para 64 verificações. Antes disso, doze dos treze goldens caíam em
   `unit` e um em `int`: **dois dos quatro ramos do leitor nunca tinham sido
   exercitados.**
2. ~~**A curva de transição.**~~ **FEITO** — §0.4.
3. ~~**O primeiro header real.**~~ **FEITO**, e ele reescreveu a §1 e abriu a
   §3.D.
4. **Mais headers, e a pergunta mudou.** Não é mais *"existe `DATAMAX`?"* — a
   resposta medida é não. É:

   > **Que fração dos arquivos que as pessoas trazem assina quem os escreveu?**

   Por fonte, o mesmo formato da §1.1: chaves, `HISTORY` completo, e mínimo /
   máximo / mediana. O que decide entre D-com-residual e B é **quantos caem no
   residual**.

   E um caso que vale procurar de propósito: **um arquivo escrito por script**
   (`astropy`), que é o candidato natural a não assinar nada.

5. **A tabela de escritores**, se a cobertura justificar — com a verificação de
   contradição da §3.D.4 desde o primeiro dia, porque é ela que separa *"confiar
   no header"* de *"confiar no header e conferir contra os pixels"*.
6. Só então o conserto, com o que ele mudar na spec do Módulo 0.

---

## Pista, n=2: o problema mora nos empilhamentos, não nas capturas — 2026-09-23

Dois headers públicos de programas de captura (N.I.N.A. e ZWO ASIAIR),
procedência OBSERVADO EM EXEMPLO PÚBLICO, mostram a mesma representação:
`BITPIX 16`, `BZERO 32768`, `BSCALE 1` — inteiro sem sinal, **escala declarada
pelo contêiner**, degrau 1. O ramo `int` já trata isso certo, conferido sem mudar
nada.

**A pista:** os casos difíceis desta investigação — float sem declaração de
escala, o ramo `/max`, o penhasco do `mx <= 1.5` — são todos saídas de
**empilhador**. As capturas cruas chegam como inteiro de escala declarada e não
passam por nenhum deles.

**Não é conclusão.** n=2, os dois de programas de captura, e nenhum arquivo foi
aberto aqui. O que isso sugere para o corpus: a população que decide a §1 é a dos
arquivos **processados**, e é ela que tem que estar no corpus — um corpus só de
capturas cruas responderia a pergunta errada.

Detalhe e procedência: `spec-escala-decisao.md`, *"As três chaves de escritor"*.
