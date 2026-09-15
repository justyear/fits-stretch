# Investigação: a regra linear / não-linear

**Status: a pergunta central FECHADA pela curva da §7 — a mediana não decide. O
que a medição exigia do log está IMPLEMENTADO (§10). O conserto da regra em si —
o 0,05 e o 0,02 — espera o corpus de headers reais (item 1).**

**Origem:** a inversão de prioridade da `spec-escala-decisao.md` §6.3. A escala
**erra alto** — branco ou preto, e se anuncia. Esta regra **erra baixo**: medido,
uma imagem 38% mais escura que parece escolha estética. **Errar baixo é o que
este projeto recusa em todo lugar**, então esta vem antes.

A regra, hoje, em `run.js`:

```js
var nonLinear = (globalMedian >= 0.05) || (historyHits.length > 0 && globalMedian >= 0.02);
```

---

## 1. A pergunta é a mesma da escala, e a resposta provavelmente também

**Linear-ou-não-linear não é uma propriedade dos pixels: é uma CONVENÇÃO sobre o
que o arquivo já sofreu.** Um quadro com mediana 0,25 pode ser um empilhamento
linear de um alvo brilhante ou um quadro já esticado — os números são os mesmos,
e a diferença está no que aconteceu antes, não no que está no array.

É exatamente a forma do problema da escala, e a §3.D de lá já tem a resposta:
**ler o escritor**. A hipótese é que o `HISTORY` do Siril diz `autostretch` em
palavras quando houve esticamento — e a §3.1 mostra que isso hoje é **crença e
não medição**, o que é justamente o que decide se um arquivo a mais é preciso.

**E a regra já lê o `HISTORY` — só que como coadjuvante.** Hoje `historyHits`
entra apenas para *baixar* o limiar de 0,05 para 0,02. A declaração é tratada
como indício que ajusta uma heurística, quando ela é a evidência mais forte
disponível.

---

## 2. Primeira medição: os dezoito fixtures e o arquivo real

| | mediana | `HISTORY` | veredito |
|---|---|---|---|
| `nonlinear` | 0,24672 | `Autostretch, Histogram Transf., Midtones transfer` | **NÃO-LINEAR** |
| outros dezessete | 0,011 a 0,049 | *vazio* | LINEAR |
| **arquivo real** (Siril 1.4.4) | 0,001177 | *"additive+scaling normalized"* — **sem palavra de esticamento** | LINEAR |

**Dezoito de dezoito concordam**, e a concordância vale pouco: dezessete são
trivialmente lineares e um é trivialmente não-linear. O que vale é outra coisa:

> **O único quadro não-linear da suíte declara que é, em palavras. E o arquivo
> real declara o que fez — `normalized`, não `autostretch` — que é a resposta
> certa para um empilhamento linear.**

n=1 do lado real, e a mesma pergunta da escala fica de pé: **que fração dos
arquivos com assinatura declara o esticamento?**

## 2.1 E um achado que estava na suíte: o `bigobject` senta na beirada

```
bigobject    mediana 0,04938     limiar 0,05     LINEAR
```

**Está 1,2% abaixo do penhasco.** `0,05 / 0,04938 = 1,013`:

> **Um aumento de exposição de 1,3% inverte o veredito deste fixture.**

Compare com o que a curva da escala mediu: o `gradient` precisa de **200%** para
cruzar o mesmo limiar. A margem não é uma propriedade da regra — é uma
propriedade do quadro, e um dos fixtures da suíte já está encostado.

E o `HISTORY` do `bigobject` é vazio nas duas bordas do penhasco: **a declaração
não se move**, enquanto a mediana atravessa. É o argumento de estabilidade, e ele
está medido dentro de casa.

> Ninguém notou que o `bigobject` estava a 1,3% do limiar porque **nada na suíte
> pergunta a que distância de um limiar um fixture está.** Golden pergunta se
> mudou, referência pergunta se os dois concordam, controle negativo pergunta se
> a cota reprova. **Distância até a fronteira não é pergunta de nenhum deles.**

---

## 2.2 O ramo dos 0,02 agora tem o outro lado — e ele derrubou uma frase

`fixture-declaraestica` entrou para o caso que a regra existe para resolver e
nunca tinha visto: **`HISTORY` declarando autostretch com a mediana em 0,0101**,
metade do limiar de 0,02.

O veredito saiu **certo** — LINEAR, os dois termos da regra falham. **A frase
saiu falsa:**

> *"Data is linear: median 0.01010, **no stretch recorded in the header**."*

O header registra `Autostretch` e `Midtones transfer`. A frase era incondicional
e **nunca teve como ser contradita**: o único outro fixture com história de
esticamento está a onze vezes do limiar, então sempre caiu no ramo de cima.

O que entrou no lugar diz **a decisão**, não só o estado:

> *The header records Autostretch and Midtones transfer, but the pixels do not
> support it: the median sits at 0.01010, under the 0.02 this rule needs before
> it takes the header at its word. Treated as linear... the file says one thing
> and its own values say another, and this line is which one was believed.*

**É a única linha do log em que uma afirmação do header é sobreposta por uma
medição**, e até agora ela não dizia que isso tinha acontecido.

E o inventário de margens registrou a mudança sozinho: `linear.medianaComHistoria`
saiu da lista de *"robusto por acidente"* — de *"o mais próximo está a 1.134%"*
para **49,5%**, com população dos dois lados.

> **Um ramo sem fixture não é só um ramo não testado: é um ramo cujas frases
> ninguém leu.** O código daquele caminho passou por revisão; o texto que ele
> emite, nunca — porque ninguém nunca o viu impresso.

**E a pergunta da §4.4 fica mais afiada:** o `0,02` resolve a contradição
*baixando o limiar*, e agora dá para ver o que isso significa em prosa. A
ferramenta **descarta o que o arquivo declara** com base numa medição — que é
exatamente a decisão que a §3 da spec da escala chama de **contradição entre as
duas fontes**, e onde a resposta proposta lá é **recusar**. As duas regras tratam
o mesmo desacordo de formas opostas, e isso é um item de decisão, não de detalhe.

## 3. A hipótese a testar

> **Se o `HISTORY` responder, a regra dos 0,05 vira degrau 5 também — e o mesmo
> conserto resolve as duas.**

Na precedência da `spec-escala-decisao.md`:

```
4. PROGRAM/CREATOR + HISTORY    o escritor declarou o que fez     <- decide
5. mediana >= 0,05              a ferramenta escolhe               <- so quando mudo
```

**Uma tabela de escritores, duas perguntas.** A entrada do Siril já teria que
distinguir `normalized` de `autostretch` para a escala; distinguir *"houve
esticamento"* é a mesma leitura, do mesmo campo, na mesma passada.

**E a conferência de falsificação vale igual:** um `HISTORY` que declara
autostretch num quadro de mediana 0,001 é uma contradição entre as duas fontes,
e recusar ali é a mesma decisão da §3 de lá.

---

### 3.1 O par é NECESSÁRIO, e decide em vez de confirmar

A pergunta: se o arquivo linear já traz `normalized output` e **não** traz nada
de esticamento, a regra não poderia ser simplesmente **a ausência de declaração
de esticamento**, usando o catálogo de termos que já existe?

**Não, e o motivo é de procedência, não de lógica.**

A regra *"ausência de declaração ⇒ linear"* só vale se o escritor for **conhecido
por declarar esticamento**. Isso é uma propriedade do escritor, não do arquivo:
ausência de evidência só é evidência de ausência quando a fonte é conhecida por
ser minuciosa **naquela operação**.

**E é exatamente isso que não está estabelecido.** O catálogo existe:

```js
var STRETCH_HISTORY = [
  [/autostretch/i,        'Autostretch'],
  [/histogram\s*transf/i, 'Histogram Transf.'],
  [/asinh/i,              'Asinh stretch'],
  ...
];
```

**Ele não tem origem escrita em lugar nenhum.** Sem comentário, sem entrada na
spec do Módulo 0, sem linha no `NOTAS`. Sete padrões sobre o que outros programas
escrevem, e nenhum registro de onde vieram — **a mesma forma das três chaves que
eu chamei de decisivas e que não existiam no arquivo real.**

E o agravante fecha o círculo: o `HISTORY` do `fixture-nonlinear` — a única
evidência na suíte de que um programa declara esticamento — **fui eu que
escrevi**, no gerador, para casar com o que eu acreditava que o Siril grava. É
zero informação pela mesma razão que contar `PROGRAM` nos fixtures é zero
informação: a população confirma quem a escreveu.

**O que muda conforme a resposta, e as duas respostas são úteis:**

| se o Siril, ao esticar, | então |
|---|---|
| **escreve** um termo de esticamento | o catálogo ganha a primeira entrada medida; `declaresStretch: true` para o Siril, e a **ausência** passa a decidir |
| **não escreve** nada | ausência não prova nada para o Siril; `declaresStretch: false`, e a mediana segue decidindo **para esse escritor** |

A segunda seria a que ninguém suspeitaria, e é a que a suposição atual esconde.

### 3.2 E o pedido encolhe: UM arquivo, não um par

A metade linear já existe e já foi medida. **Falta um único arquivo:** um quadro
qualquer com o autostretch do Siril aplicado, salvo, e as linhas de `HISTORY`
reportadas.

```
o que trazer:   so as linhas HISTORY, e a mediana
o que nao:      OBJECT, DATE-OBS, TELESCOP, INSTRUME, nome, caminho, pixel
```

Esse arquivo responde as duas perguntas de uma vez: **se** o Siril declara, e
**com que palavra** — que é o que valida ou corrige as sete linhas do catálogo.

## 4. O que medir antes de propor

1. ~~**Quantos fixtures estão perto de um limiar absoluto.**~~ **FEITO:**
   `test/compare-margens.ps1`, e virou verificação em vez de relatório. Achou
   dois casos dentro de 5% — o `bigobject` (§2.1) e o `fixture-saturation`, que
   recusa o recorte a **2,8%** do piso de 20%, com os dois números impressos no
   log desde sempre.

   **E respondeu uma pergunta desta investigação de graça:** o ramo
   `historyHits && mediana >= 0,02` tinha **um único fixture aplicável, a 1.134%
   do limiar** — nunca exercitado dos dois lados, robusto por acidente e não por
   escolha. **Fechado pelo `fixture-declaraestica`** (§2.2): a distância caiu
   para 49,5% e o limiar tem população dos dois lados.

2. **UM arquivo do Siril já esticado**, §3.2 — e ele decide, não confirma.

3. ~~**A curva desta regra**, como a da escala.~~ **FEITA — §7.** 111 rodadas em
   quatro fixtures, com ganho e com pedestal. Ela derrubou a regra: ver §8. O
   `bigobject` deu o caso apertado de graça e o degrau caiu entre `k=1,0124` e
   `k=1,0126`, com a saída indo de 21 para 11.

4. **O que o `0,02` está fazendo — e agora com o caso à vista.** Ele existe para
   *"o header diz esticado mas a mediana está baixa"*, que é **precisamente a
   contradição** da §3 da spec da escala. Hoje ele a resolve **baixando o
   limiar**, ou seja: **descartando o que o arquivo declara, com base numa
   medição.**

   A spec da escala chama exatamente esse desacordo de contradição entre as duas
   fontes, e propõe **recusar**. **As duas regras tratam o mesmo desacordo de
   formas opostas** — e isso é decisão, não detalhe.

   O `fixture-declaraestica` põe o caso na mesa: hoje ele sai LINEAR, com o log
   dizendo qual das duas fontes ganhou. A pergunta é se ganhar é o certo.

## 5. O que esta investigação NÃO faz

- **Não propõe limiar novo.** Trocar 0,05 por outro número escolhido repete o
  defeito com outro valor.
- **Não implementa nada.** A tabela de escritores é uma só, e ela pertence à
  decisão da escala — esta investigação decide se a mesma tabela responde as
  duas perguntas.
- **Não mede o que precisa de arquivo real.** Os itens 1 e 2 da §4 dependem de
  headers que ainda não existem aqui.

---

## 6. O que já dava para dizer, antes da curva

**A regra de hoje não está errada — está sem autoridade.** Ela acerta os dezoito
fixtures e o arquivo real. O que ela não tem é uma razão para o `0,05` que não
seja *"funciona nos casos que olhamos"*, e um fixture a 1,3% da fronteira é o
lembrete de que "funciona" e "tem margem" são coisas diferentes.

**E o `HISTORY` tem a autoridade que falta:** ele não estima o que aconteceu com
o arquivo, ele **registra**. A pergunta desta investigação não é se a declaração
é melhor que a mediana — é **quantos arquivos trazem a declaração**, que é a
mesma pergunta que trava a decisão da escala, sobre a mesma população.

> **A curva da §7 foi mais longe do que isto.** *"Sem autoridade"* era generoso:
> a §8 mede que a regra **não é invariante** a duas transformações que preservam
> a classe, e uma regra assim não está sem autoridade — está medindo outra coisa.
> A pergunta *"quantos arquivos trazem a declaração"* continua de pé, e passou a
> ser a única.

---

## 7. A CURVA, medida — e ela responde mais do que a pergunta

**111 rodadas da cadeia inteira**, em quatro fixtures, pelo `__loadFromURL` do
build com ganchos. Duas perturbações, e a escolha das duas é o argumento inteiro:

```
ganho     v -> k*v       tempo de exposicao, ganho do sensor
pedestal  v -> v + d     offset de bias, poluicao luminosa, ceu mais claro
```

**Controle do instrumento, antes de qualquer número:** o caminho de perturbação
com `k=1, d=0` devolve o arquivo **byte a byte** — 0 bytes diferentes em
5.763.600 amostras — e o veredito bate com o golden. Um instrumento que muda a
resposta na identidade não é instrumento.

### 7.1 O degrau, visto de perto

`bigobject`, ganho, passo 0,0002 em `k`:

```
k         mediana      veredito     saida (mediana)   saida (media)
1,0000    0,0493833    LINEAR             21             22,01
   ...                 LINEAR             21   em 13 pontos
1,0124    0,0499987    LINEAR             21             22,02
1,0126    0,0500038    NAO-LINEAR         11             11,75
   ...                 NAO-LINEAR         11   em 16 pontos
1,0200    0,0503751    NAO-LINEAR         11             11,83
```

**A saída é plana dos dois lados e troca de uma vez.** Isso não é decoração: é o
controle que atribui o salto ao ramo e não ao ganho. Entre `k=1,0000` e
`k=1,0124` o ganho cresce 1,24% e a saída não se move **um nível de 255**.

O mecanismo, do mesmo par de rodadas:

```
              mediana      shadows     midtones    saida
k=1,0124     0,0499987    0,034598     0,107434      21
k=1,0126     0,0500038    0,035584     0,176471      11
```

**A entrada andou 5,1e-06. O `midtones` andou 64%.**

| | |
|---|---|
| variação da entrada | **+0,0102%** |
| variação da saída | **−47,6%** |
| amplificação no penhasco | **≈ 4.700×** |

E os 5,1e-06 são **exatamente o quantum do instrumento**: a mediana sai de um
histograma de 65.536 bins (passo 1,526e-05) e a regra usa a **média de três
canais**, então o menor passo possível é 1,526e-05 / 3 = 5,086e-06. A escada
está na varredura, degrau por degrau. **A posição do penhasco é definida até o
último bin e não além dele.**

### 7.2 O pedestal: 41 ADU

Mesma cena, mesmo processamento, só o céu mais claro:

```
d          mediana      veredito      saida    d em ADU de 16 bits
0,00060    0,0499835    LINEAR          21          39,3
0,00061    0,0499936    LINEAR          21          40,0
0,00062    0,0500038    NAO-LINEAR      11          40,6
0,00070    0,0500852    NAO-LINEAR      11          45,9
```

**Somar 41 ADU a cada pixel inverte o veredito e escurece a saída pela metade.**
Quarenta e um ADU é menos que o offset de bias da maioria das câmeras.

E a inclinação medida fecha o que isso significa:

```
d(mediana)/d(pedestal) = 1,000     (dentro de um quantum, em 13 pontos)
d(mediana)/d(ganho)    = mediana   (dentro de um quantum, em 31 pontos)
```

> **A entrada da regra é uma função afim do nível do céu e do ganho da câmera.**
> Ela mede o céu e o sensor. Não mede o que foi feito com o arquivo.

### 7.3 O outro lado: o arquivo que declara e é esticado assim mesmo

`nonlinear`, ganho **para baixo**. As três linhas de `HISTORY` — `Autostretch`,
`Histogram Transf.`, `Midtones transfer` — estão presentes em **todas** as
rodadas:

```
k          mediana      hits   veredito       saida
0,0811     0,0199995      3    LINEAR           22
0,0812     0,0200300      3    NAO-LINEAR        4
```

**Salvar o mesmo arquivo esticado a 8,1% do nível faz a ferramenta esticá-lo de
novo, por cima, com o header dizendo três vezes que não devia.** A saída sai
5,5× mais clara que o tratamento honesto — e este é o erro na direção que a
ferramenta diz que não comete.

### 7.4 E num fixture o limiar é INALCANÇÁVEL

`declaraestica` precisa de `k = 1,98` para chegar ao limiar de 0,02. O penhasco
da escala chega em `k = 1,50`:

```
k=1,499   mediana 0,015152   LINEAR   saida  21
k=1,501   mediana 0          LINEAR   saida   0     <- 100% preto
```

Em `k=1,501` o `normalisePhysical` troca para `/65535`, a mediana lida vira
**zero** e a imagem inteira sai preta. **O limiar desta regra nunca é atingido
nesse arquivo: o outro penhasco destrói a imagem antes.**

### 7.5 A ordem dos dois penhascos depende do conteúdo — de novo

| | `k` da regra | `k` da escala | quem chega primeiro |
|---|---|---|---|
| `nonlinear` | **0,0811** | 1,50 | regra (para baixo, longe da escala) |
| `bigobject` | **1,0125** | 3,68 | **regra** |
| `declaraestica` | 1,9799 | **1,50** | escala |
| `gradient` / `asinh` | **2,9834** | 3,18 | **regra** |
| `colour` | 3,0595 | **1,50** | escala |
| `edge`, `rice`, `saturation`, `mudo` | 3,19–3,28 | **1,50–1,63** | escala |
| `twoobjects` | **3,6707** | 3,71 | **regra** |
| `oneobject` / `cropped` | 3,9815 | **3,70** | escala |
| `seestar`, `nobayer`, `bayerespelhado` | 4,5468 | — | inteiro, sem penhasco |
| `flatsky` | **4,5489** | 63,9 | **regra** |

Seis contra sete, e **a ordem muda com a imagem**. É o mesmo achado da §0.4 da
investigação da escala, agora do outro lado: não existe um "fator seguro" único
para declarar a ninguém.

*(A coluna da escala só vale para os fixtures no ramo `/1`. Os que já entram por
`/65535` ou `/max` têm outra fronteira e estão marcados com um traço.)*

### 7.6 Segundo degrau medido, para não ser peculiaridade de um fixture

`gradient`, em volta de 2,98:

```
2,982   0,0499936   LINEAR        21     (21 em 4 pontos abaixo)
2,983   0,0500089   NAO-LINEAR    12     (12 em 5 pontos acima)
```

−43% de saída para **+0,03%** de ganho. Mesma forma, outro conteúdo, outro ponto
do eixo.

---

## 8. A RESPOSTA: a mediana não decide — e a prova não depende de quem escreveu os fixtures

### 8.1 O argumento, e ele é de invariância

Um arquivo linear é, por definição, **afim no fluxo**: valor = ganho × fótons +
offset. Então:

> **Ganho e pedestal preservam a classe.** Um quadro linear multiplicado por `k`
> continua linear; somado de `d` continua linear. Um quadro esticado
> multiplicado por `k` continua esticado — a curva de tom que já foi aplicada não
> se desaplica.

E foi medido que **a regra não é invariante a nenhum dos dois**, em quatro
instâncias, com controle plano dos dois lados de cada uma.

> Nenhum limiar sobre a mediana pode ser invariante a ganho e a offset, porque a
> mediana não é. **O defeito não é o número 0,05: é o eixo.**

**E é por isso que esta medição vale, sendo os fixtures meus.** Ela nunca
pergunta *"em que classe este arquivo está"* — pergunta se a resposta da regra é
estável sob uma transformação que **não pode** mudar a classe, seja ela qual for.
Uma medição que não precisa saber a verdade não pode ser confirmada pela mão que
escreveu a população. É a primeira desta investigação com essa propriedade.

### 8.2 O que a suíte NÃO prova, e é importante dizer

A tentação era escrever *"os dois arquivos que declaram esticamento ocupam as
duas pontas da ordenação pela mediana"* — o que é verdade e é quase nada:

- `nonlinear` é o **único** arquivo da suíte com pixels esticados, e o gerador
  que escreveu os pixels e o que escreveu o `HISTORY` **sou eu**;
- `declaraestica` **não é um arquivo esticado**: é um arquivo linear com um
  header que declara esticamento, construído de propósito para a contradição.

Então a suíte tem **um** membro da classe "esticado", de origem conhecida.
Qualquer argumento de separabilidade sobre essa população pergunta à minha
própria decisão se ela foi tomada. **O argumento da §8.1 não precisa dela.**

### 8.3 O que o 0,02 vale, medido

Sem declaração o limiar é 0,05; com declaração, 0,02. **A autoridade inteira do
header vale um fator 2,5 num eixo em que a população linear observada já varia
42×** — de 0,001177 (o arquivo real do Siril, linear) a 0,049383 (`bigobject`).

E em `declaraestica` esse fator **não pode nem ser exercido**: o penhasco da
escala chega antes (§7.4).

> O `0,02` não é a regra ouvindo o header. É a regra **descontando** o header e
> continuando a decidir sozinha.

### 8.4 A estrutura que sobra é a proposta, com uma correção

A da `spec-escala-decisao.md`, e ela carrega:

```
4. PROGRAM/CREATOR + HISTORY    o escritor declarou o que fez   <- decide
5. mediana >= 0,05              a ferramenta escolhe            <- so no mudo
```

O degrau 4 tem o primeiro dado **MEDIDO**: o Siril 1.4.4 grava
`Histogram Transf.` com os parâmetros quando estica de verdade — dois arquivos,
dois alvos, mesma sessão. E a declaração é a única grandeza que **não se moveu em
nenhuma das 111 rodadas**: `hits` ficou em 0, 2 ou 3 conforme o arquivo, qualquer
que fosse `k` ou `d`. Invariância medida, não argumentada.

**A correção que a medição impõe, e ela não estava na proposta:** o degrau 5 não
é um empate honesto. Ele erra **47,6% de brilho** numa perturbação de 1,25%, e em
alguns arquivos é inalcançável. Quando ele decidir, **o log tem que dizer que
decidiu por ausência de declaração e a que distância do limiar ficou** — a mesma
disciplina de contingência que a escala já ganhou.

### 8.5 A porta que esta medição NÃO fecha

A §2.2 da investigação da escala fechou *"nenhuma estatística resolve"* por um
argumento definicional: dois arquivos com os mesmos valores têm que receber o
mesmo ramo. **Aqui esse argumento não se aplica do mesmo jeito**, e seria fácil
esticá-lo sem perceber.

O que a §8.1 fecha é a mediana e **qualquer limiar sobre ela**. Uma estatística
*afim-invariante* — assimetria, forma do histograma, `(mediana − moda)/MAD` — não
é derrubada por ela, e um quadro linear e um esticado **têm** formas diferentes.

Contra isso há um argumento no limite: um esticamento suave o bastante (uma MTF
com `m` perto de 0,5) é quase afim na faixa ocupada, e produz um arquivo esticado
por convenção e afim-próximo do original. Mas **argumento no limite não é
medição**, e medir isto precisa de população esticada real — **o item 1**.

> A porta da estatística de forma fica **aberta e nomeada**. Ela não muda a
> ordem: o corpus destrava as duas de qualquer jeito.

---

## 9. E um achado de instrumento, na regra que esta investigação mede

**`linearity.globalMedian` e `linearity.nonLinear` são comparados por 0 das 709
comparações.** As duas linhas existem no `compare-reference.ps1` e ficam
**abaixo** do `continue` que pula todo fixture com um passo que a `reference.py`
não modela — e hoje isso é todo fixture.

Não é um campo esquecido: é um campo **escrito, com o valor do outro lado
disponível**. A `referencia-cadeia.json` traz `esticamento.nonLinear` para os doze
fixtures dela. Ninguém lê.

E as duas pontas medem **grandezas diferentes com o mesmo nome** — isto é leitura
do código das duas, não medição da segunda ponta, que não roda nesta máquina:

| | onde a mediana é medida |
|---|---|
| JS (`run.js`) | no quadro **decodificado**, antes da extração de fundo |
| `chain2.py` | em `pl2`, **depois** de fundo e calibração de cor |

O lado JS está medido: `linearity.globalMedian` é **byte a byte** igual à mediana
do `before` do passo `background` nos 19 fixtures. E a distância entre os dois
pontos de medição, medida nos mesmos 19, vai de **−8,72% a +7,37%** — com o pior
caso no `bigobject`, que é justamente o que está a 1,25% do limiar. **Sete vezes
a própria margem.**

A banda de discordância, rodada a rodada:

```
bigobject, k de 1,0126 a 1,11    JS diz NAO-LINEAR; no ponto de medicao da
                                 outra ponta a grandeza ainda esta abaixo
                                 9,7% de exposicao com um ramo cada
```

Nenhum fixture cai nessa banda hoje, então nada reprova. **E se caísse, o que
apareceria seriam FAILs numéricos do bloco `stretch`** — que é exatamente o que o
comentário do próprio comparador chama de *"descrever o sintoma em vez do fato"*,
seis linhas acima do `continue` que causa isto.

**Proposta, não implementada:** comparar `esticamento.nonLinear` no bloco
`cadeia`, que roda para todo fixture, e declarar o ponto de medição de cada lado
como divergência conhecida com a banda medida. Uma linha booleana que reprova
antes das outras.

### 9.1 FEITO — e o conserto é a guarda, não o remendo

A comparação subiu para **antes de todo `continue`**, dos dois lados: o laço do
Módulo 0 compara `globalMedian` e `nonLinear` contra a `justyear-referencia.json`
(0,40 e 0,28 bins de 4 — passa), e o laço da cadeia compara `nonLinear` contra
`esticamento.nonLinear` para os doze. O `seestar` sai **N/A com o valor
impresso** e o motivo dito, porque a referência mede o mosaico.

**A mediana continua não sendo comparada entre as duas pontas, e agora isso é uma
linha** — `globalMedian (ponto de medicao)`, N/A, com a banda de −8,72% a +7,37%
escrita nela. Comparar os dois números seria comparar duas coisas diferentes e
chamar a diferença de divergência.

O que impede a repetição não é a mudança de lugar:

```
suite   linearidade   (guarda)   20 / 20   PASS
```

Todo fixture com golden tem que sair com uma linha de `linearidade` — comparada,
ou N/A com o motivo. Controle negativo da guarda: renomeando o escopo, ela
reprova nomeando os nove fixtures que perdem a linha.

**750 comparações, 0 FAIL. 401 campos sob varredura de controle negativo.**

---

## 10. O que a §8.4 exigia, implementado

A correção que a medição impôs — *"o degrau 5 não é um empate honesto"* — está no
log. Quando nada no header declara esticamento:

> *… **Nothing in the header declares a stretch, so the median decided this on
> its own — a 1.25% rise in the frame's overall level would reverse it.***

A distância é `limiar / mediana`, **derivada e não escolhida**: nenhum número novo
entrou, nem limiar nem piso de "perto". E ela é a conta feita, não os dois lados
para o leitor subtrair.

E a quarta saída da regra ganhou fixture: `fixture-ceuclaro.fit`, empilhamento
linear de céu de cidade, mediana **0,0805**, header mudo. É o caso em que a
mediana decide sozinha **contra** o arquivo, e era o único dos quatro sem ninguém
que lesse a frase.

**O que NÃO mudou, e era o pedido:** o `0,05` e o `0,02` estão onde estavam. O
conserto espera o corpus.
