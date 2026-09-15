# Investigação: a normalização de FITS float

**Status: investigação. Nada implementado, e a decisão não está tomada.**

**Origem:** revisão cruzada. Os três ramos de `normalisePhysical` são

```js
bitpix > 0    -> faixa do contêiner, [BZERO + BSCALE*min, BZERO + BSCALE*max]
mx <= 1.5     -> já está em [0,1], divisor 1
mx <= 70000   -> divisor 65535 ("float numa escala de 16 bits")
senão         -> divisor = mx, o MAIOR PIXEL DO QUADRO
```

A objeção: o último ramo faz **um pixel definir a escala do quadro inteiro**, e
dois empilhamentos do mesmo alvo podem normalizar diferente.

---

## 0. A pergunta que decide o tamanho do problema, medida antes de discutida

> *"Se a cadeia inteira for invariante a escala multiplicativa, o ramo `/max` é
> feio mas inofensivo. Se não for, é grave."*

**Medido, não argumentado.** O instrumento: cópias do `fixture-gradient.fit`
(float32, 1600×1200×3, máximo 0,4713) com todos os pixels multiplicados por *k*,
header preservado byte a byte. Mesma geometria, mesma estrutura, só a escala
física diferente.

### 0.1 O resultado, em quatro linhas

| k | ramo | regra linear | mediana do quadro | **mediana da saída (G, 8 bits)** | pretos |
|---|---|---|---|---|---|
| 1 | `unit`, ÷1 | LINEAR | 0,016759 | **22** | 0,11% |
| 2 | `unit`, ÷1 | LINEAR | 0,033529 | **22** | 0,11% |
| 3 | `unit`, ÷1 | **NÃO-LINEAR** | 0,050294 | **13** | 0,08% |
| 4 | **`float16`, ÷65535** | LINEAR | ~0 | **0** | **99,98%** |

**A resposta é "as duas coisas", e a distinção é o achado:**

**1. O núcleo do esticamento É invariante a escala.** k=1 contra k=2 — exatamente
2× de diferença física, mesmo ramo, mesma regra — dá a **mesma imagem**: mediana
22 nos dois, média 25,47 contra 25,49 (0,08% de diferença, que é o dither). A MTF
se renormaliza: `shadows` e `midtones` mudam (0,01383 → 0,02767 e 0,03149 →
0,06211), e o resultado não muda. Isso é a etapa fazendo o que promete.

**2. Os LIMIARES ABSOLUTOS a montante não são.** Existem dois, e os dois foram
medidos cruzando:

```
mx <= 1.5        a fronteira do proprio ramo de normalizacao
                 k=3 -> max 1,414  (passa)
                 k=4 -> max 1,885  (CRUZA)  ->  99,98% da imagem preta

mediana >= 0.05  a regra linear/nao-linear, em run.js
                 k=2 -> 0,0335     (passa)
                 k=3 -> 0,0503     (CRUZA)  ->  algoritmo diferente,
                                                saida 38% mais escura
```

**A falha é discreta, não gradual.** Entre k=1 e k=2 nada acontece. Entre k=2 e
k=3 a imagem escurece 38% porque o esticamento trocou de algoritmo. Entre k=3 e
k=4 a imagem some. **Um fator 4 de exposição separa "idêntico" de "preto".**

### 0.2 O ramo `/max` e a estrela quente, medidos

O `/max` roda só quando `mx > 70000`. Cópia do mesmo quadro ×200000 (máximo
94.269), e uma segunda cópia idêntica **com um único pixel em 3× o máximo**:

| | divisor | mediana do quadro | estrelas | rejeitadas por saturação | ganho R | **saída (mediana G)** |
|---|---|---|---|---|---|---|
| sem o pixel quente | 94.269 | 0,035569 | 14.974 | 40 | 1,013773 | **22** |
| **com um pixel 3×** | **282.807** | **0,011856** | 15.015 | **0** | 1,012758 | **22** |

**Um pixel mudou o divisor do quadro inteiro por 3× e a imagem não mudou.** Média
25,48 contra 25,53, pretos 0,11% nos dois.

Mas **a mediana do quadro caiu de 0,0356 para 0,0119** — e a mediana é a entrada
da regra `>= 0,05`. O pixel quente não estraga a imagem: ele **move o quadro para
outro lugar em relação aos limiares**. Um quadro cuja mediana caísse em 0,06
seria não-linear; com uma estrela quente a mais, linear. **Mesmo alvo, mesma
noite, duas entregas diferentes.**

E todo número que o log imprime muda: `rejeitado.saturado` 40 → 0, `estrelas`
14.974 → 15.015, `ganho R` na quinta casa. **O log é o produto.** Números que
mudam por causa de um pixel são números que descrevem o instrumento, não o céu.

### 0.3 Veredito da §0

**Não é "feio mas inofensivo", e não é "toda imagem está errada".** É uma
**troca de ramo latente**: a cadeia tolera escala, os portões dela não. O `/max`
é perigoso não pelo que faz com os pixels, mas por **mover a entrada dos dois
limiares de forma que ninguém declarou**.

Isso muda o desenho do conserto. Não adianta "adivinhar melhor a escala": o que
precisa mudar é **de que os dois limiares dependem**.

---

## 1. O que existe de fato como convenção

**Esta seção é a que ainda não está medida, e ela é a razão de isto ser uma
investigação e não uma spec de implementação.** O que está escrito aqui é o que
se acredita hoje, com o nível de confiança marcado. **Nada aqui vira código antes
de ser verificado contra arquivo real** — e "arquivo real" aqui significa
verificado **fora desta árvore**, pela regra do `CLAUDE.md`.

| escritor | o que se acredita | confiança | como confirmar |
|---|---|---|---|
| **Siril** | float32 já em [0,1]; grava `HISTORY` das operações e tem keywords próprias | **alta** — é o caso que o ramo `mx <= 1.5` atende e que já apareceu aqui | abrir um `.fit` de saída do Siril e listar os cartões |
| **Seestar (S30/S50)** | subs e stack em inteiro de 16 bits, `BZERO = 32768` | **alta** — é o que o `fixture-seestar` reproduz e o que o ramo `bitpix > 0` trata | idem, num sub e num stack |
| **PixInsight** | internamente [0,1]; ao exportar FITS de 32 bits pode gravar em [0,1] **ou** na faixa do contêiner, conforme a opção de exportação | **média** — há uma opção envolvida, e uma opção é uma coisa que o usuário erra | exportar o mesmo arquivo pelos dois caminhos e comparar |
| **astropy** | grava o array como ele está: **não há convenção nenhuma**, a escala é a que o script tinha | **alta** — é uma biblioteca, não um aplicativo | — |
| **fpack / funpack** | preserva `BITPIX`; para float aplica quantização por padrão (`-q`), reversível com o dither registrado no header | **média-alta** — o `fixture-rice` exercita o caminho | conferir os keywords de quantização num `.fz` de origem conhecida |

**A pergunta que esta tabela não responde, e é a que importa:** existe algum
escritor que grave float **fora** de [0,1] e **fora** da escala de 16 bits, num
intervalo que o ramo `/max` esteja realmente atendendo? Se não existir, o ramo
`/max` não tem população — e pela regra da §2 do Módulo 5a, **um portão sem
população é um portão que não devia existir**. Se existir, ele precisa de um
critério que não seja o maior pixel.

**Medir isso é a primeira tarefa**, e ela é barata: um inventário de cabeçalhos
de arquivos de origem conhecida, rodado fora da árvore, reportando só
`BITPIX / BZERO / BSCALE / BUNIT / DATAMAX` e o escritor — nunca `OBJECT`,
`DATE-OBS`, `TELESCOP`, `INSTRUME` nem o nome do arquivo.

---

## 2. O que dá para inferir COM SEGURANÇA do header

Em ordem de força. **"Seguro" aqui quer dizer: se o keyword está lá e é válido,
ele decide; se não está, não se inventa.**

| evidência | o que decide | força |
|---|---|---|
| **`BITPIX > 0`** | a escala é a do contêiner, e isso **já é o que o código faz** — inteiro não é ambíguo | **decide sozinho** |
| **`BSCALE` / `BZERO`** | a transformação física; para float quase sempre 1 / 0, e valores diferentes disso são uma declaração explícita do escritor | **decide sozinho quando presente e ≠ (1,0)** |
| **`DATAMAX` / `DATAMIN`** | o escritor declarou a faixa **dos dados**. É a única coisa no header que pode legitimar um divisor, porque veio de quem escreveu, não do maior pixel | **forte quando presente** — e é exatamente o que falta hoje |
| **`BUNIT`** | a unidade física (`ADU`, `electron`, `Jy`...). Não dá a escala, mas `BUNIT` presente é sinal de que os valores **não** são [0,1] normalizado | **indiciária** |
| **`HISTORY` de quem escreveu** | já é lido para a regra não-linear. Identifica o escritor, e o escritor implica a convenção da tabela da §1 | **forte, mas indireta** — depende da §1 estar medida |
| **o maior pixel** | **nada.** É uma propriedade de uma estrela, não do formato | **não decide** |

A última linha é o ponto inteiro. `DATAMAX` e o maior pixel podem ter o mesmo
valor numérico e não são a mesma afirmação: um é o escritor dizendo *"a faixa é
esta"*, o outro é o quadro dizendo *"o pixel mais brilhante é este"*. **Hoje o
código usa o segundo como se fosse o primeiro.**

---

## 3. Quando a resposta certa é RECUSAR ou DECLARAR, em vez de adivinhar melhor

O produto inteiro se apoia em *"nada acontece com os pixels que não esteja
escrito"*. Um divisor escolhido por heurística **é** algo que acontece com os
pixels, e hoje ele está escrito no log — a linha *"Pixel values divided onto 0–1
by the largest value in the frame"* existe e nomeia o divisor. O que ela não diz
é a **consequência**, que é a §0.2.

Três respostas possíveis, e a escolha não está feita:

**A. DECLARAR A CONSEQUÊNCIA.** O ramo fica como está e o log ganha o que falta:
que o divisor veio de um único pixel, e que dois arquivos do mesmo alvo podem
normalizar diferente por causa disso. É o mínimo, é barato, e é a mesma forma
das correções do CFA e da calibração — *declarar a suposição e o que acontece se
ela estiver errada*.

**B. RECUSAR.** Quando `mx > 70000` e não há `DATAMAX`, `BUNIT` nem `HISTORY`
que identifique o escritor, a ferramenta **não tem base para escolher escala** e
diz isso, em vez de produzir uma imagem plausível a partir de um palpite. É
consistente com a decisão da §1.2 do Módulo 5a (*"o botão não aparece quando a
promessa não vale"*) e com a do recorte (*"não sugere e diz por quê"*).

**C. TIRAR O RAMO.** Se a §1 mostrar que ninguém grava float nessa faixa, o ramo
não tem população real e cai na classe mais cara já registrada: **a suíte podia
confirmar um portão que a população real quase nunca atravessa**. A pergunta é a
mesma: *antes de manter um ramo, qual fração da população real passa por ele?*

**A escolha depende da §1, e é por isso que a §1 vem antes.** Nenhuma das três é
"adivinhar melhor".

---

## 4. O que muda no resto da cadeia se a escala mudar

Medido na §0. Esta seção é a lista, etapa por etapa, do que é invariante e do
que não é — e é ela que diz **onde** o conserto tem que mexer.

| etapa | grandeza que decide | invariante a escala? | medido |
|---|---|---|---|
| **decode** | `mx` contra 1,5 e 70000 | **NÃO — é a própria fronteira** | k=3 → k=4 cruza; imagem some |
| **regra linear/não-linear** | `mediana >= 0,05` | **NÃO — limiar absoluto em dado linear** | k=2 → k=3 cruza; saída 38% mais escura |
| **extração de fundo** | mediana + σ·MADN das caixas | **sim** — relativo por construção | pedestal e modelo escalam junto |
| **seleção estelar (piso)** | `mediana + 12·MADN` | **sim** | — |
| **seleção estelar (teto)** | `ccStarMax = 0,85` | **NÃO — absoluto em dado linear** | `rejeitado.saturado` 0 → 8 → 296 de k=1 a k=3 |
| **razões estelares e ganhos** | razão acima do pedestal | **sim** — é um quociente | ganhos batem na 3ª casa em todos os k |
| **esticamento MTF** | `shadows = mediana + σ·MADN`, alvo 0,085 na SAÍDA | **sim** | k=1 e k=2 dão a mesma imagem |
| **saturação seletiva** | SNR e joelho 0,80, **depois** do esticamento | **sim** | opera no eixo já normalizado pela MTF |
| **recorte sugerido** | `Y > céu + 2,5σ`, **depois** do esticamento | **sim** | recusou nos quatro k |
| **quantise** | 8 bits da saída esticada | **sim** | — |

**Três não-invariantes, e as três estão a montante do esticamento.** Tudo que
roda **depois** da MTF é invariante, porque a MTF renormaliza. Tudo que roda
**antes** e usa um número absoluto não é.

**A forma do conserto sai daqui, e ela não é sobre o divisor:** as três grandezas
que decidem — `mx`, a mediana do quadro e o teto de 0,85 — são absolutas num
eixo que o próprio decode escolheu. Enquanto forem, qualquer divisor é uma
escolha com consequência. **A alternativa é torná-las relativas a algo medido no
quadro** (a mediana e o MADN já estão lá), e aí o divisor deixa de decidir
nada — o que também tornaria o ramo `/max` inofensivo de verdade em vez de por
sorte.

---

## 5. O que esta investigação NÃO fez

- **Não tocou em código.** As cópias escaladas foram construídas por um
  instrumento de medição fora da árvore e apagadas depois; nenhum fixture novo
  foi versionado.
- **Não mediu arquivo de terceiro.** Tudo saiu do `fixture-gradient.fit`,
  sintético e reprodutível.
- **Não fechou a §1**, que é a única que decide entre A, B e C — e é a próxima.
- **Não propôs limiar novo.** Trocar 0,05 por outro número escolhido seria
  repetir o defeito com outro valor.

## 6. Ordem sugerida

1. **Inventário de cabeçalhos** de arquivos de origem conhecida, fora da árvore,
   reportando só formato e escritor. Fecha a §1 e decide entre A, B e C.
2. **Fixture para cada ramo de normalização.** Medido nos treze goldens: **doze
   caem em `unit` (÷1) e um em `int` (÷65535, o `seestar`). Os ramos `float16` e
   `floatmax` não têm nenhum caso na suíte** — e o `floatmax` é justamente o que
   esta revisão apontou. Dois dos quatro ramos do decode nunca foram exercitados
   por um teste.

> **O item 2 é dívida nomeada e vale por si**, independentemente do que a §1
> decidir: um ramo sem fixture é um ramo que ninguém verificou, e este projeto
> já pagou essa conta duas vezes.
