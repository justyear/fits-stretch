# Spec de decisão: como a escala de um FITS float é escolhida

**Status: spec de decisão. Só a §4.3 está implementada. A §3 mudou: a
contradição declara, não recusa.**
**Evidência:** `investigacao-escala-float.md` — toda medição citada aqui está lá.

---

## 0. A decisão, em uma linha

> **A escala vem de quem escreveu o arquivo, conferida contra os pixels. Quando
> ninguém assinou — ou quando a declaração e os pixels discordam — a ferramenta
> escolhe, e diz que escolheu.**

O que muda: hoje a decisão salta das chaves do padrão FITS direto para uma
estatística sobre os valores. Entre as duas existe um degrau — **a declaração do
escritor** — e é nele que mora o caso mais comum do público-alvo.

---

## 1. A §1 fechou: os dois extremos, medidos

| | caso principal | caso residual |
|---|---|---|
| exemplo medido | empilhador de telescópio inteligente → Siril 1.4.4 | `astropy.io.fits.writeto` simples |
| `DATAMIN`/`DATAMAX`/`BUNIT` | **ausentes** | **ausentes** |
| `PROGRAM`/`CREATOR`/`PRODUCER` | **presentes** | **ausentes** |
| `HISTORY` | *"additive+scaling normalized input, normalized output"* | **0 cartões** |
| total de chaves | — | **seis**: `SIMPLE BITPIX NAXIS NAXIS1 NAXIS2 EXTEND` |

**Não há meio-termo, e é bom que não haja.** O `astropy` não acrescenta nada por
conta própria: quem escreve tem que **decidir** escrever, e quem decide escrever
normalmente escreve o suficiente. A regra fica binária:

> **ou o arquivo declara quem o escreveu, ou não declara.**

Uma regra binária sobre uma população bimodal é uma regra que não tem zona
cinzenta para errar — e zona cinzenta é onde limiar escolhido vira dívida.

---

## 2. A precedência

Cinco degraus. **Cada um só é consultado se os anteriores não decidiram**, e o
log diz qual decidiu.

```
1. BITPIX > 0                      a escala e a do conteiner          PADRAO
2. BSCALE/BZERO diferentes de (1,0) transformacao declarada           PADRAO
3. DATAMIN / DATAMAX               faixa declarada pelo escritor      PADRAO
4. PROGRAM / CREATOR + HISTORY     o escritor, declarado              DECLARACAO
5. estatistica sobre os valores    escolha da ferramenta              ESCOLHA
```

**1–3 são o padrão FITS**: se estão lá e são válidos, decidem, e não há opinião a
ter. **4 é declaração de quem gravou** — não é estimativa, é alguém dizendo o que
fez. **5 é escolha da ferramenta**, e é o único degrau em que ela está adivinhando.

Hoje a decisão vai de 1–2 para 5. **O degrau 4 é o que falta, e é onde o caso
principal mora.**


### A procedência dos degraus, medida no FITS Support Office

**Achado em 2026-09-23**, depois que alguém no grupo de astrofotografia apontou
`fits.gsfc.nasa.gov`. Não resolve a metade esticada do corpus — é tudo dado de
ciência —, mas move a **procedência dos degraus** de suposição para documento.

O dicionário de palavras-chave do padrão está em
<https://heasarc.gsfc.nasa.gov/docs/fcg/standard_dict.html>, e o das demais
convenções em <https://heasarc.gsfc.nasa.gov/docs/fcg/common_dict.html>.

| chave | onde está documentada | status |
|---|---|---|
| `BUNIT` | **FITS Standard**, reservada | DOCUMENTADO |
| `DATAMIN` / `DATAMAX` | **FITS Standard**, reservadas | DOCUMENTADO |
| `HISTORY` / `COMMENT` | **FITS Standard**, reservadas | DOCUMENTADO |
| `CREATOR` | recomendação **HEASARC** (`ofwg_recomm/r7.html`) | DOCUMENTADO |
| `PROGRAM` | **UCOLICK** — convenção local de um observatório | FRACO |
| `PRODUCER` | **não aparece** em nenhum dos dois dicionários | SEM ORIGEM |
| `ROWORDER`, `BAYERPAT`, `XBAYROFF`, `YBAYROFF` | **não aparecem** | SEM ORIGEM |

**O degrau 3 fica mais forte do que estava escrito.** `DATAMIN`/`DATAMAX` são
reservadas do padrão, com texto normativo:

> *"The value field shall always contain a floating point number, regardless of
> the value of BITPIX. This number shall give the minimum valid physical value
> represented by the array, exclusive of any special values."*

`shall`. Quando estão lá, não há o que interpretar — que é exatamente o que o
degrau 3 já assumia, e agora com a citação.

**E o degrau 4 ganha a base que lhe faltava.** A entrada de `HISTORY` diz:

> *"This keyword shall have no associated value; columns 9-80 may contain any
> ASCII text. The text should contain a history of steps and procedures
> associated with the processing of the associated data. Any number of HISTORY
> card images may appear in a header."*

**Ler o `HISTORY` para saber o que foi feito com o arquivo não é invenção
nossa: é o uso que o padrão designa para o campo.** A investigação da regra
linear (§8.4) chegou a isso por medição; o padrão chega pelo outro lado.

> **E a palavra que decide a §1 inteira é `should`, não `shall`.**
>
> O padrão RECOMENDA registrar o processamento e não OBRIGA. Um arquivo que não
> diz nada sobre o que sofreu **está em conformidade**. Então o caso mudo não é
> arquivo malfeito nem escritor desleixado: é o padrão sendo seguido.
>
> Isso fecha uma pergunta que a spec tratava como aberta — *"dá para exigir a
> declaração?"*. Não dá. O degrau 5 tem que existir, e a pergunta que resta é só
> **que fração declara**, que continua precisando do corpus.

**O que isto NÃO move:** as sete entradas do `STRETCH_HISTORY`. O padrão diz que
`HISTORY` guarda o histórico de processamento e **não diz com que palavras** —
nenhum texto prescrito, nenhum vocabulário. As entradas SUPOSTO continuam
SUPOSTO, e só fecham com arquivos de cada programa.

**E uma correção que isto impõe à escada:** o degrau 4 trata `PROGRAM` e
`CREATOR` como equivalentes, e eles não são. `CREATOR` é recomendação HEASARC;
`PROGRAM` tem como única origem a convenção local de **um** observatório. Os dois
fixtures da suíte trazem `PROGRAM`, porque foi o que o gerador escreveu — outra
população que confirma quem a escreveu. **Anotado, não consertado:** qual das
duas os programas de astrofotografia realmente gravam é pergunta para o corpus.

### As três chaves de escritor, com a procedência de cada — 2026-09-23

**Um nível de procedência novo entra aqui, e ele vale para o projeto inteiro:**

```
MEDIDO                        abrimos o arquivo e lemos o header
OBSERVADO EM EXEMPLO PUBLICO  alguem publicou o header; ninguem aqui abriu o
                              arquivo nem conferiu que o header nao foi
                              editado antes de publicado
DOCUMENTADO                   esta escrito num dicionario ou numa documentacao
SUPOSTO                       ninguem verificou
```

`OBSERVADO EM EXEMPLO PÚBLICO` é **mais fraco que `MEDIDO`**, e a diferença é
uma só: quem mede aqui não pode excluir que o header tenha sido editado. Em
relação a `DOCUMENTADO` ele não é mais forte nem mais fraco — responde outra
pergunta. A documentação diz o que um programa **deveria** gravar; a observação
diz o que **um** arquivo, uma vez, mostrou.

A origem são dois headers públicos de programas de **captura**, encontrados por
um parceiro de teste:

```
N.I.N.A.   SWCREATE = 'N.I.N.A. 2.0.0.9001'   BITPIX 16  BZERO 32768  BSCALE 1
ASIAIR     CREATOR  = 'ZWO ASIAIR Plus'       BITPIX 16  BZERO 32768  BSCALE 1
```

| chave | dicionários do FITS Support Office | arquivo real aberto aqui | exemplo público |
|---|---|---|---|
| `PROGRAM` | UCOLICK, convenção local — FRACO | MEDIDO: nomeia o programa que **salvou** o arquivo (Siril) | — |
| `CREATOR` | recomendação HEASARC — DOCUMENTADO | MEDIDO: nomeia o **dispositivo de captura**, não o Siril | ASIAIR, nomeando a captura |
| `SWCREATE` | **em nenhum dos dois** — SEM ORIGEM | — | N.I.N.A., nomeando a captura |
| `PRODUCER` | em nenhum dos dois — SEM ORIGEM | MEDIDO: o fabricante | — |

**Não equivalentes, e agora por dois motivos.** Um é de procedência: cada uma tem
a sua, e elas não se somam. O outro é de **sentido**, e apareceu ao reler o
arquivo real: os dicionários definem `PROGRAM` e `CREATOR` com **o mesmo texto**
— *"the program that originally created the current FITS HDU"* — e no único
arquivo real aberto aqui as duas nomeiam **escritores diferentes**. `PROGRAM`
diz quem salvou; `CREATOR`, de onde veio a captura. A definição diz uma coisa e a
prática diz outra.

**Pista, com n=3 e não conclusão:** nos três headers vistos, a chave que nomeia a
*captura* é `CREATOR` ou `SWCREATE`, e a que nomeia o *processamento* é
`PROGRAM`. Se isso se sustentar no corpus, o degrau 4 não lê "o escritor" — lê
**dois**, e eles respondem perguntas diferentes.

**Decisão de quem conduz: registrar as três e não unificar ainda.** A linha do
degrau 4 na escada continua como está.

#### A representação numérica dos dois exemplos, e o que ela já tem

`BITPIX 16 + BZERO 32768 + BSCALE 1` é o inteiro de 16 bits sem sinal, e é o
**degrau 1**: o contêiner declara a escala. O ramo `int` de `normalisePhysical` o
trata assim, conferido sem mudar nada: `lo = 0`, `hi = 65535`, divisor 65535,
`scaleSource = container`. No `fixture-seestar`, que tem **exatamente** essa
representação, o máximo observado (20650) vai para 0,315 — **não** é esticado
para 1,0. E a implementação Python independente concorda nas dez linhas de decode
desse fixture, `rawMin` e `rawMax` exatos.

#### O que os dois exemplos NÃO resolvem, e isto vai escrito

**Linear contra esticado continua aberto.** São capturas cruas: lineares por
física, e mudas por declaração — o `HISTORY` deles, se existe, não foi mostrado.
**Nenhuma entrada do `STRETCH_HISTORY` se move por causa deles.**

**O que eles sugerem, com n=2, como pista:** o problema da normalização de float
mora nos **empilhamentos processados**, e não nas capturas cruas, que chegam como
inteiro de escala declarada. Os casos difíceis da investigação da escala — float
sem declaração, o ramo `/max` — são todos saídas de empilhador. Anotado como
pista, não como conclusão.

### 2.1 O degrau 4, com a única forma que ele pode ter

Uma tabela de escritores, na forma da `STRETCH_HISTORY` que já existe em
`run.js` — regex sobre as linhas de `HISTORY`, mais as chaves de assinatura. Não
é mecanismo novo: é a segunda aplicação de um que já passou por revisão, já
alimenta a regra linear/não-linear, já vai para o record e já é impresso no log.

**Cada entrada da tabela declara três coisas, e a terceira é a que a torna
auditável:**

```
quem        o padrao que identifica o escritor
o que       a escala que aquela declaracao implica
como sei    a frase do HISTORY ou a chave que sustenta, VERBATIM
```

**O log imprime qual entrada casou e o texto que a sustentou.** Uma tabela de
comportamento de terceiro envelhece — se o Siril mudar de convenção, a entrada
fica errada. Imprimir o texto que casou faz a entrada velha aparecer **no
artefato**, onde alguém lê, em vez de só no código, onde ninguém olha.

#### A primeira linha da tabela: o Siril — MEDIDO, 2026-09-24

A representação que o escritor grava, medida na parte A de
`medicao-escritores.md`: pixels sintéticos de `medicao_escritores.py` (semente
20260923), o header e os pixels de saída gravados pelo próprio Siril, a mesma
entrada byte a byte nas duas versões.

| escritor | identifica-se por | representação gravada | carregar e salvar | `DATAMAX` da entrada | procedência |
|---|---|---|---|---|---|
| Siril 1.4.4 | `PROGRAM = 'Siril 1.4.4'` | float32 (`BITPIX -32`); `BZERO 0` e `BSCALE 1` **gravados**, mesmo em float | pixels **idênticos** à entrada | **apagado** | MEDIDO — Windows, `siril-cli` |
| Siril 1.2.1 | `PROGRAM = 'Siril v1.2.1'` | idem | idem | **apagado** | MEDIDO — Linux (Ubuntu 24.04), `siril-cli` |

**Como sei, verbatim** (`medicao-escritores-relatorio-a.txt` para o 1.4.4,
`medicao-escritores-ensaio.txt` para o 1.2.1):

```
as 16 saidas, nas duas versoes   BITPIX -32 BZERO 0.0 BSCALE 1.0
s00-base e s00b-base-limpa       BASE: pixels identicos a entrada
s00-base                         chaves removidas: { ... 'DATAMAX': [...] }
```

`BZERO` e `BSCALE` estão **no arquivo**, não são o padrão que o leitor supõe
quando a chave falta: o relatório os lê do header e imprimiria `None` se
faltassem, e o bloco de header desta ferramenta mostra `BZERO = 0` e
`BSCALE = 1` no `fixture-escritor-base`, e não `(absent)`.

**O que a linha diz sobre a escada, neste caminho:**

- **degrau 2 não decide.** `BZERO 0` e `BSCALE 1` gravados são a identidade, e o
  degrau só consulta valores *diferentes* de (1, 0). A presença das duas chaves
  num float do Siril **não** é o contêiner declarando a escala;
- **degrau 3 não decide.** O `DATAMAX` que a entrada trazia sai apagado — um
  arquivo que passou pelo Siril não chega com faixa declarada desatualizada,
  chega sem nenhuma;
- então um float do Siril cai no **degrau 4 ou no 5**, e o 4 precisa aceitar as
  duas formas da string, com e sem o `v`.

**Escopo — o que a linha NÃO cobre:** entrada float32 RGB com valores dentro de
[0, 1] (de 0,0032 a 0,871); operações por comando. Não medidos: entrada inteira,
mono, float fora de [0, 1], o diálogo *Salvar como* (parte B), o arquivo que sai
do empilhamento. "Pixels idênticos" vale para esta entrada e não diz o que o
Siril faz com um float fora de [0, 1].

### 2.2 O degrau 5 não some

Ele continua existindo para o arquivo mudo, e continua sendo o que é hoje. O que
muda é **quantos arquivos chegam nele** e **o que o log diz quando chegam** — §4.

---

## 3. A conferência de falsificação

**Este é o achado de desenho da rodada**, e ele é o que separa esta spec de
"confiar no header".

Uma declaração de escala é **falsificável pelos próprios pixels**, de graça — o
máximo já é calculado no decode:

```
declaracao CONSISTENTE com os dados   ->  usa a declaracao          (degrau 4)
declaracao CONTRADITA pelos dados     ->  degrau 5, com aviso FORTE (3.1)
sem declaracao                        ->  degrau 5, declarando      (secao 4)
```

**Medido no arquivo real:** `HISTORY` diz *"normalized output"*, máximo
**1,000000000 exato**. Consistente.

**A forma da conferência, por tipo de declaração:**

| declaração | contradita quando |
|---|---|
| "normalizado para [0,1]" | `max > 1` além do épsilon de float32 |
| faixa explícita `[a,b]` | `min < a` ou `max > b` |
| "escala de 16 bits" | `max > 65535` |

> **Confiar e conferir é uma promessa diferente de confiar.** A primeira degrada
> para um aviso explícito quando a fonte falha; a segunda degrada para uma imagem
> errada com aparência de certa.

### 3.1 A contradição NÃO recusa — e esta seção mudou de posição

**A versão anterior desta spec mandava RECUSAR na contradição.** A razão parecia
boa: as duas únicas fontes de verdade discordam, e escolher uma seria a
ferramenta decidindo qual mentiu.

**Estava inconsistente com a §4 desta mesma spec**, e a inconsistência foi
apontada de fora: a §4 argumenta que declarar é honesto quando o erro se anuncia
e a decisão é inevitável. **Escolher uma escala é inevitável nos dois casos** — o
mudo e o contraditório. Não existe versão de "abrir o arquivo" que pule isso.

**O que a medição diz, e ela é o que decide.** Quatro contradições construídas
sobre o `fixture-gradient`, cada uma com a declaração de um lado e os pixels do
outro, caindo no degrau 5:

| contradição | ramo do degrau 5 | **saída (mediana G)** | média |
|---|---|---|---|
| *nenhuma* — o quadro como ele é | `unit` ÷1 | **22** | 25,47 |
| declara `[0,1]`, pixels vão a 15.083 | `float16` ÷65535 | **22** | 25,51 |
| declara `[0,1]`, pixels vão a 94.269 | `floatmax` ÷94.269 | **22** | 25,48 |
| declara `16 bits`, pixels vão a 0,566 | `unit` ÷1 | **22** | 25,50 |

**As quatro dão a MESMA imagem, e é a imagem certa.** O degrau 5 acerta o quadro
em todas as contradições testadas — porque a MTF renormaliza e nenhuma delas
cruza um limiar absoluto.

**E obedecer à declaração contradita seria PIOR nas duas direções:**

```
declara [0,1] e os pixels vao a 15.083  ->  obedecer (÷1) estoura tudo: BRANCO
declara 16 bits e os pixels vao a 0,566 ->  obedecer (÷65535) da PRETO
```

Ou seja: **a contradição não é um caso em que a ferramenta precisa escolher entre
duas verdades. É um caso em que uma das duas está velha, e os pixels são a que
não envelhece.**

**O único resultado errado que a contradição produz é ALTO:**

```
max 1,508 (declaracao [0,1] contradita por pouco)  ->  99,98% PRETO
```

Branco e preto não são plausíveis. Ninguém publica um quadro preto achando que
deu certo.

### 3.2 O caso plausível-e-errado existe — e NÃO é da contradição

Procurado de propósito, e ele aparece:

```
k=2,9   rawMax 1,367   mediana 0,04862   LINEAR       saida 22
k=3,0   rawMax 1,414   mediana 0,05029   NAO-LINEAR   saida 13
```

**Uma imagem 38% mais escura, que parece escolha estética.** É o hazard que a §4
não encontrou na escala — e ele **não é causado pela contradição**: é a regra dos
0,05 sendo cruzada. **Acontece igual num arquivo mudo, e igual num arquivo com
declaração perfeitamente consistente.**

Então ele não distingue a contradição do resto, e não pode justificar tratá-la
diferente. Ele justifica outra coisa, e é a razão de a
`investigacao-regra-linear.md` ter virado prioridade.

### 3.3 A contradição tem MAIS informação, não menos — e é isso que o aviso usa

O argumento que fecha a mudança:

> **O arquivo mudo e o contraditório recebem o mesmo tratamento porque o degrau 5
> é o mesmo código com os mesmos modos de falha. Mas o contraditório sabe mais, e
> o aviso dele diz mais.**

No mudo, a ferramenta só pode dizer *"nada aqui declara a escala; eu escolhi"*.
No contraditório, ela pode dizer **as duas coisas e qual valeu**:

> *This file's header says it was written normalised to 0–1, and its pixels run
> to 15083 — the two disagree. The header is the one that can go stale: a later
> program can rescale the values without recording it. The scale below was taken
> from the pixels, not from that line, and the picture is the same either way —
> but if the header is right and the pixels were damaged, nothing here can tell.*

**Recusar jogaria essa informação fora junto com o arquivo.** E a forma é a mesma
do CFA e da calibração — a suposição, a consequência, e o que não é detectável.

### 3.4 E as duas regras passam a ter a mesma forma

Era a inconsistência que motivou a mudança, e some com ela:

| desacordo | antes | agora |
|---|---|---|
| header diz esticado, pixels dizem que não (regra dos 0,02) | descarta o header, processa | **processa, dizendo qual venceu** |
| header diz normalizado, pixels dizem que não (escala) | **RECUSA** | **processa, dizendo qual venceu** |

**Duas instâncias do mesmo problema, com a mesma resposta, diferindo só na força
do aviso.** É o que se espera de duas instâncias do mesmo problema — e a linha da
regra dos 0,05 já foi escrita nessa forma nesta sessão: *"the file says one thing
and its own values say another, and this line is which one was believed."*

**O que continua recusando:** nada, nesta spec. A recusa segue existindo para o
que o corpus `malformed` já cobre — arquivo que não é FITS, geometria impossível,
dado cortado. **Contradição entre header e pixels não é malformação: é um header
velho, e um header velho tem um arquivo bom embaixo.**

## 4. O arquivo mudo: DECLARAR, e eu não tenho argumento contra

**Proposta: processar, escolhendo pelo degrau 5, com a escolha e a consequência
escritas no log.** Não recusar.

**E eu procurei o argumento contra, porque este projeto tem uma regra que parece
se aplicar.** A regra é a da meia escala: *"dizer a verdade num texto que ninguém
lê não é o mesmo que não prometer"* — de onde saiu o botão que não aparece, o
recorte que não sugere, e a recusa do CFA quando a suposição não se sustenta.

**Ela não se aplica aqui, e o motivo é medido.**

### 4.1 Por que a regra da recusa não alcança este caso

A regra existe para o resultado **plausível e errado** — aquele em que a pessoa
não tem como perceber. Medido, é o que acontece quando o degrau 5 erra:

| erro do degrau 5 | o que a pessoa vê |
|---|---|
| escolhe `÷1` quando era escala de 16 bits | **branco** — tudo estoura |
| escolhe `÷65535` quando já era [0,1] | **99,98% preto** |
| escolhe `/max` quando era outro | **a mesma imagem** — medido no par `float16`/`floatmax`: `shadows`, `midtones` e `clipLow` idênticos |

**Nenhuma das três é plausível-e-errada.** Duas são catastróficas e
autoanunciantes — ninguém publica um quadro branco achando que deu certo. A
terceira não muda a imagem.

**Recusar protegeria de quê?** De um erro que a própria imagem denuncia. E
custaria a função inteira para um caso legítimo: um script que grava float em
ADU é um arquivo correto, escrito por alguém que sabe o que fez.

> **Este é o oposto do caso da meia escala, e vale registrar por quê.** Lá o erro
> era invisível (1,07 em vez de 2,0 de redução de ruído) e a promessa era
> opcional — dava para não prometer. Aqui o erro é visível e a decisão é
> obrigatória: não existe versão de "abrir o arquivo" que não escolha uma escala.
> **Quando o erro se anuncia e a decisão é inevitável, declarar é a resposta
> honesta; recusar é higiene performática.**

### 4.2 O que o log diz no caso mudo

A frase segue a forma que esta rodada aplicou ao CFA e à calibração — **a
suposição e a consequência**, não só a suposição:

> *Nothing in this file says what scale it was written on: no DATAMAX, no BUNIT,
> and no program name or history. The values were divided onto 0–1 by [o
> critério], which is this tool's choice and not something the file declared. The
> picture is unaffected by that choice — but the decisions below that compare
> against fixed levels are not, and they are marked.*

### 4.3 E a parte que é quieta, que é onde meu meio-argumento sobrevive

Não há hazard plausível-e-errado **na imagem**. Há um **nos números** — e os
números são o produto.

Com a escala escolhida pela ferramenta, as **medições** continuam verdadeiras do
quadro como ele foi processado. O que fica contingente são as **decisões
condicionadas a limiares absolutos**: a regra linear/não-linear e o teto de 0,85
da seleção estelar.

**Essas decisões o log tem que marcar como contingentes.** É a diferença entre
*"a mediana é 0,0168"* — que é verdade — e *"os dados são lineares"* — que é
verdade **dada uma escala que ninguém declarou**.

> **FEITO, e é a única parte desta spec já implementada.** O decode emite
> `scaleSource`: `container` quando `BITPIX`/`BZERO` decidiram, `chosen` quando a
> ferramenta escolheu. Com `chosen`, o veredito de linearidade e a contagem acima
> do teto de 0,85 saem com a cláusula que diz de que escolha elas dependem — e só
> essas duas, porque marcar tudo é não marcar nada.
>
> **A consequência apareceu na suíte sem que ninguém a escrevesse:** dos dezoito
> fixtures, `seestar` e `nobayer` são os únicos cuja escala vem do contêiner, e
> são **exatamente** os dois cujo veredito sai sem qualificação. A frase aparece
> e some sozinha, com o motivo.
>
> Quando o degrau 4 entrar, ele acrescenta `declared` a `scaleSource` e as
> decisões deixam de ser contingentes nos arquivos com assinatura — que é o caso
> principal.

---

## 5. Onde a evidência é lida

### 5.1 No `.fz`, o header já é o certo

Medido no `fixture-rice.fit.fz`: o HDU primário tem **quatro cartões** —
`SIMPLE`, `BITPIX`, `NAXIS`, `EXTEND` — e tudo mais mora na extensão `BINTABLE`.

**E o código já lê o header certo.** `findImageHDU` devolve, para arquivo
comprimido, o header da extensão, com `map`, `cards` e `history` dela — o
comentário no lugar já diz *"os keywords comuns (BAYERPAT, ROWORDER, HISTORY) já
estão sentados neste mesmo header"*. **Nada a mudar**; a spec só precisa dizer
que o degrau 4 lê o header do HDU que `findImageHDU` devolveu, e não o primário.

**Um cuidado que vale escrever:** num `.fz`, `PROGRAM` nomeia quem escreveu a
**imagem**, não quem a comprimiu. O `fpack` aparece separado, em `ZCMPTYPE` e
companhia. Uma entrada da tabela que casasse `fpack` responderia a pergunta
errada.

### 5.2 `HISTORY` é append-only: o último a escrever é o que vale

O parser preserva a ordem do arquivo — `history.push(...)` na varredura dos
cartões — então a **última** linha é a operação mais recente.

**A regra:** quando mais de uma linha de `HISTORY` fala de escala, **a última
vence**. Um arquivo normalizado e depois reescalado por outro programa traz as
duas declarações, e só a segunda descreve o que está nos pixels.

### 5.3 A assimetria do parser, que a spec tem que assumir

`HISTORY` acumula em ordem; **chave repetida, porém, mantém a PRIMEIRA**:

```js
if (!(parsed.key in map)) map[parsed.key] = parsed.value;
```

São semânticas **opostas**, e as duas são defensáveis: `HISTORY` é um diário e o
fim é o presente; chave repetida é header malformado e a primeira é a menos
surpreendente. Mas o degrau 4 lê os dois, então a spec fixa:

> **A assinatura (`PROGRAM`/`CREATOR`) identifica quem escreveu; o `HISTORY`
> identifica o que foi feito por último. Quando discordam, vale o `HISTORY`** —
> porque um programa que reescreve pixels sem trocar `PROGRAM` é exatamente o
> caso que a §6.2 declara não detectar, e o `HISTORY` é a única chance de pegá-lo.

---

## 6. O que D remove, e o que D não remove

### 6.1 Remove: uma folga que ninguém derivou

**Medido:** a saída normalizada do Siril fixa o máximo em **1,000000000 exato**.
Não "perto de 1": exato, por construção.

Então **toda a população do caso principal senta no mesmo ponto do eixo**, e a
distância dela até o penhasco — `mx > 1,5` — é **50% de exposição**. Essa folga
não veio de medição nenhuma: veio de a constante `1,5` ter sido escolhida como
*"um pouco acima de 1"*.

**Funciona hoje, e ninguém derivou por quê.** É uma constante que separa
corretamente uma população inteira por uma razão que não está escrita — o tipo de
acerto que sobrevive até o dia em que um escritor normaliza para 1,2, ou até
alguém mexer no número sem saber o que ele está segurando.

**D remove a dependência:** com a declaração lida, o `1,5` deixa de decidir o caso
principal. Ele continua existindo, no degrau 5, para o arquivo mudo — onde é
honestamente um palpite e o log diz que é.

### 6.2 Não remove: o que fica declarado como não detectável

| | detectável |
|---|---|
| outro programa **acrescentou** `HISTORY` | **sim** — §5.2, a última linha vence |
| declaração **contradiz** os pixels | **sim** — §3, e vira aviso forte com as duas afirmações nomeadas |
| outro programa **reescreveu pixels sem registrar nada** | **NÃO** |

A terceira vai para o log, pela mesma regra do CFA: *a escala veio do que o
arquivo declara; se ele passou por outro programa que mudou os valores sem
registrar, a escala pode estar errada e nada aqui percebe.*

### 6.3 NÃO remove, e esta é a mais importante: a regra dos 0,05

**D resolve a escolha da escala. Não resolve a regra linear/não-linear**, que é
um limiar absoluto separado, e é **ela** que tem o modo de falha plausível-e-errado
que a §4.1 não encontrou na escala:

```
gradient, k=3,0    mediana cruza 0,05     saida 22 -> 13
```

Uma imagem **38% mais escura** não se anuncia. Não é branca, não é preta: parece
uma escolha estética. E isso acontece **com a escala perfeitamente declarada** —
o arquivo do Siril tem mediana 0,001177, longe do limiar, mas nada garante que o
próximo tenha.

> **É aqui que o "declarar em vez de recusar" da §4 tem limite.** A escala erra
> alto; a regra dos 0,05 erra baixo, e errar baixo é o que este projeto recusa em
> todo lugar.
>
> **A ordem foi invertida: a regra dos 0,05 vem primeiro** —
> `investigacao-regra-linear.md`. E a hipótese dela é que o conserto é o mesmo:
> linear-ou-não-linear também é uma **convenção sobre o que o arquivo já sofreu**,
> não uma propriedade dos pixels, e o `HISTORY` do Siril diz `autostretch` em
> palavras quando houve esticamento. Se a declaração responder, a regra dos 0,05
> vira degrau 5 também e **a mesma tabela de escritores resolve as duas**.

---

## 7. O que a suíte precisa — os três casos, FEITOS

1. ~~**Um fixture MUDO.**~~ `fixture-mudo`: os seis cartões do `astropy` e nada
   mais. Os quatorze anteriores traziam `PROGRAM` porque o gerador os escreve, e
   o caso residual — metade da decisão — não tinha caso.
2. ~~**Um arquivo que se CONTRADIZ.**~~ `f1-declara-normalizado-mente`, no corpus
   `malformed`. **E o sentido dele mudou com a §3.1:** ele não vira `rejeita`
   quando a conferência entrar — continua `aceita`, e o que passa a existir é o
   **aviso**. O caso segue valendo, e prova outra coisa: hoje a contradição passa
   em **silêncio**, e é o silêncio que vai mudar.
3. ~~**Um arquivo com DUAS declarações de escala no `HISTORY`.**~~
   `fixture-duasdecl`, e ele **discrimina**: as duas leituras possíveis dão
   vereditos opostos sobre o mesmo arquivo.

**O que falta agora está do outro lado:** a tabela de escritores precisa de mais
de um arquivo por escritor, e a §1 está em n=1.

---

## 8. O que esta spec não decide

- **A tabela de escritores**, que é o conteúdo do degrau 4. Ela precisa de mais
  de um arquivo por escritor para existir sem inventar entradas. n=1 por enquanto.
- **O critério do degrau 5.** Continua sendo o de hoje até que alguém o derive;
  trocar `max` por um percentil conserta a fragilidade a um pixel (§2.1 da
  investigação) e **não** conserta a ambiguidade, então é melhoria e não solução.
- **A regra dos 0,05** — §6.3. **É o próximo item, e virou investigação própria:**
  `investigacao-regra-linear.md`.
- **Separar leitura de decisão** em `normalisePhysical` (§2.3 da investigação).
  Continua registrado e não feito.
