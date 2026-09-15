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

**O que a medição mudou na pergunta:** a escala, sozinha, é quase inofensiva. O
perigo é o **acoplamento entre a escala e limiares absolutos a montante** — e
esse acoplamento não é sobre o divisor, é sobre de que os limiares dependem.

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

## 1. O que existe de fato como convenção — A ÚNICA SEÇÃO NÃO MEDIDA

Ela decide entre as saídas da §3 e **não vai virar código antes de ser
verificada**. Fica em confiança declarada, não em afirmação.

| escritor | o que se acredita | confiança |
|---|---|---|
| **Siril** | float32 já em [0,1]; grava `HISTORY` das operações | **alta** — é o caso que o ramo `mx <= 1.5` atende |
| **Seestar (S30/S50)** | inteiro de 16 bits, `BZERO = 32768` | **alta** — é o que o `fixture-seestar` reproduz |
| **PixInsight** | internamente [0,1]; ao exportar FITS de 32 bits pode gravar em [0,1] **ou** na faixa do contêiner, conforme opção | **média** — há uma opção, e opção é coisa que se erra |
| **astropy** | grava o array como ele está: **sem convenção nenhuma** | **alta** — é biblioteca, não aplicativo |
| **fpack / funpack** | preserva `BITPIX`; para float quantiza por padrão, com o dither no header | **média-alta** — o `fixture-rice` exercita |

### 1.1 O que trazer de cada arquivo, para fechar esta seção

Só header, **nunca pixel**, e os arquivos não entram na árvore. Por fonte
(Siril, PixInsight, fpack, Seestar), um arquivo de cada caminho que o aplicativo
oferece — no caso do PixInsight, **um de cada opção de exportação**.

**As chaves, em ordem de importância:**

```
BITPIX  NAXIS  NAXIS1  NAXIS2  NAXIS3
BZERO  BSCALE          <- a transformacao fisica declarada
DATAMIN  DATAMAX       <- a faixa DECLARADA pelo escritor: a chave da decisao
BUNIT                  <- unidade fisica; se existe, os valores nao sao [0,1]
ROWORDER
todos os HISTORY e COMMENT   <- e quem escreveu, e o que ele fez
qualquer chave nao-padrao    <- Siril e PixInsight gravam as proprias
ZIMAGE ZBITPIX ZCMPTYPE ZQUANTIZ ZDITHER0    <- so nos .fz
```

**E três números dos pixels, que não são pixels:**

```
minimo  maximo  mediana
```

São o que decide se o arquivo cai em `[0,1]`, na escala de 16 bits ou fora das
duas — e a mediana é o que diz se ele é linear ou já esticado. **Três números
por arquivo não reconstroem imagem nenhuma.**

**O que NÃO trazer, e a regra é do `CLAUDE.md`:** `OBJECT`, `DATE-OBS`,
`TELESCOP`, `INSTRUME`, o nome do arquivo, o caminho. A fonte vai como *"um
parceiro de teste"* e o escritor como classe (*"Siril 1.2"*), nunca como
identificação.

**A pergunta que a lista fecha:** existe algum escritor que grave float **fora**
de [0,1] e **fora** da escala de 16 bits — ou seja, algum arquivo real que o
ramo `/max` esteja realmente atendendo? Se não existir, ele é um portão sem
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
**header** (`DATAMAX`, `BUNIT`, `HISTORY`) ou não está em lugar nenhum. Quando
não está, a resposta honesta não é um palpite melhor — é declarar ou recusar.

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

## 3. Quando a resposta certa é RECUSAR ou DECLARAR

Três saídas, e a escolha depende da §1:

**A. DECLARAR A CONSEQUÊNCIA.** O ramo fica e o log ganha o que falta: que o
divisor veio de um punhado de pixels, e que dois arquivos do mesmo alvo podem
normalizar diferente por isso. É a mesma forma das correções do CFA e da
calibração — *declarar a suposição **e** o que acontece se ela estiver errada*.

**B. RECUSAR.** Quando `mx > 1.5` e não há `DATAMAX`, `BUNIT` nem `HISTORY` que
identifique o escritor, a ferramenta **não tem base para escolher escala** e diz
isso, em vez de produzir uma imagem plausível a partir de um palpite. É a mesma
decisão do botão que não aparece e do recorte que não sugere.

**C. TIRAR O RAMO `/max`.** Se a §1 mostrar que ninguém grava float nessa faixa,
ele não tem população real — e cai na classe mais cara já registrada aqui.

**Nenhuma das três é "adivinhar melhor".** E a §2.2 fecha a porta para uma
quarta: não existe estatística que resolva isto.

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
- **Não mediu arquivo de terceiro.** Tudo saiu de fixtures sintéticos.
- **Não fechou a §1**, que é a única que decide entre A, B e C.
- **Não propôs limiar novo.** Trocar 0,05 por outro número escolhido seria
  repetir o defeito com outro valor.

## 6. Ordem

1. ~~**Fixture para cada ramo de normalização.**~~ **FEITO.** Entraram
   `fixture-float16`, `fixture-floatmax` e `fixture-nobayer`; `compare-golden`
   foi de 52 para 64 verificações. Antes disso, doze dos treze goldens caíam em
   `unit` e um em `int`: **dois dos quatro ramos do leitor nunca tinham sido
   exercitados.**
2. ~~**A curva de transição.**~~ **FEITO** — §0.4.
3. **Inventário de cabeçalhos**, pela lista da §1.1. Fecha a §1 e decide entre
   A, B e C.
4. Só então o conserto, com o que ele mudar na spec do Módulo 0.
