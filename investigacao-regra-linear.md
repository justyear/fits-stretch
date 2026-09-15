# Investigação: a regra linear / não-linear

**Status: investigação, aberta. Medir antes de propor — a mesma forma da escala.**

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
   `historyHits && mediana >= 0,02` tem **um único fixture aplicável, a 1.134%
   do limiar**. O `0,02` **nunca foi exercitado dos dois lados** — é robusto por
   acidente, não por escolha.

2. **UM arquivo do Siril já esticado**, §3.2 — e ele decide, não confirma.

3. **A curva desta regra**, como a da escala: `k` em passos finos em volta do
   ponto em que cada fixture cruza 0,05, medindo a saída. O `bigobject` já dá o
   caso apertado de graça, a 1,3%.

4. **O que o `0,02` está fazendo.** Ele existe para o caso *"o header diz
   esticado mas a mediana está baixa"* — que é **precisamente a contradição** da
   §3 da spec da escala. Hoje ele **resolve a contradição baixando o limiar**, e
   a pergunta é se isso é o certo ou se é recusa disfarçada de heurística.

   E agora com um dado a mais: **essa resolução nunca foi exercitada.** Uma
   heurística que nunca rodou é indistinguível de uma que está errada.

## 5. O que esta investigação NÃO faz

- **Não propõe limiar novo.** Trocar 0,05 por outro número escolhido repete o
  defeito com outro valor.
- **Não implementa nada.** A tabela de escritores é uma só, e ela pertence à
  decisão da escala — esta investigação decide se a mesma tabela responde as
  duas perguntas.
- **Não mede o que precisa de arquivo real.** Os itens 1 e 2 da §4 dependem de
  headers que ainda não existem aqui.

---

## 6. O que já dá para dizer

**A regra de hoje não está errada — está sem autoridade.** Ela acerta os dezoito
fixtures e o arquivo real. O que ela não tem é uma razão para o `0,05` que não
seja *"funciona nos casos que olhamos"*, e um fixture a 1,3% da fronteira é o
lembrete de que "funciona" e "tem margem" são coisas diferentes.

**E o `HISTORY` tem a autoridade que falta:** ele não estima o que aconteceu com
o arquivo, ele **registra**. A pergunta desta investigação não é se a declaração
é melhor que a mediana — é **quantos arquivos trazem a declaração**, que é a
mesma pergunta que trava a decisão da escala, sobre a mesma população.
