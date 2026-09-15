# Spec de decisão: como a escala de um FITS float é escolhida

**Status: spec de decisão. Só a §4.3 está implementada.**
**Evidência:** `investigacao-escala-float.md` — toda medição citada aqui está lá.

---

## 0. A decisão, em uma linha

> **A escala vem de quem escreveu o arquivo, conferida contra os pixels. Quando
> ninguém assinou, a ferramenta escolhe e diz que escolheu.**

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
declaracao CONTRADITA pelos dados     ->  RECUSA                    (nao ha 5)
sem declaracao                        ->  degrau 5, declarando      (secao 4)
```

**A contradição é o único caso em que recusar é certo**, e o motivo é preciso:
as duas únicas fontes de verdade disponíveis — o que o escritor declarou e o que
os pixels mostram — **discordam entre si**. Escolher uma delas seria a ferramenta
decidindo qual das duas mentiu, e ela não tem base para isso.

**Medido no arquivo real:** `HISTORY` diz *"normalized output"*, máximo
**1,000000000 exato**. Consistente.

**A forma da conferência, por tipo de declaração:**

| declaração | contradita quando |
|---|---|
| "normalizado para [0,1]" | `max > 1` além do épsilon de float32 |
| faixa explícita `[a,b]` | `min < a` ou `max > b` |
| "escala de 16 bits" | `max > 65535` |

> **Confiar e conferir é uma promessa diferente de confiar.** A primeira degrada
> para uma recusa explícita quando a fonte falha; a segunda degrada para uma
> imagem errada com aparência de certa.

---

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
| declaração **contradiz** os pixels | **sim** — §3, e recusa |
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

## 7. O que a suíte precisa antes do conserto

Três casos, e **nenhum existe hoje**:

1. **Um fixture MUDO.** Os quatorze atuais trazem `PROGRAM` e `INSTRUME` porque o
   gerador os escreve — o caso residual, que é metade da decisão, **não tem
   caso**. Um fixture com os seis cartões do `astropy` e nada mais.
2. **Um arquivo que se CONTRADIZ**: declara normalizado e traz máximo fora de
   [0,1]. É o único caso que exercita a recusa da §3, e o lugar dele é o corpus
   `malformed` — é um arquivo que mente sobre si mesmo, que é exatamente o que
   aquele corpus coleciona.
3. **Um arquivo com DUAS declarações de escala no `HISTORY`**, para a regra da
   §5.2. Sem ele, "a última vence" é afirmação e não controle.

**O item 1 é o que impede começar.** Escrever o degrau 5 sem um fixture mudo é
escrever o caminho do caso residual sem nunca percorrê-lo — e esta sessão já
pagou essa conta três vezes.

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
