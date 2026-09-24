# Protocolo: medição de escritores — o que cada programa grava no header

*Spec de medição, escrita no chat em 2026-09-24. Destrava o item 1 pelo lado que
não depende de ninguém: o que cada escritor grava. A parte de comandos foi
ensaiada num Siril real (1.2.1) antes de chegar aqui — §3.*

---

## 0. Arquivos, e onde cada um fica

| arquivo | onde | para quê |
|---|---|---|
| `medicao-escritores.md` | raiz do repositório | este documento |
| `medicao_escritores.py` | raiz do repositório, ao lado do `reference.py` | `gera` a entrada sintética; `le` as saídas e escreve o relatório |
| `medicao-escritores.ssf` | raiz do repositório | parte A: as operações por comando, num script do Siril |
| `medicao-escritores-ensaio.txt` | raiz do repositório | o ensaio: a parte A rodada no Siril 1.2.1 |

A medição roda numa pasta **fora** do repositório: `D:\justyear image s2\medicao-escritores\`.
As saídas só entram no repositório pela mão do Claude Code, como fixtures
escolhidos (§8).

Dependências: Python com numpy e astropy, Siril 1.4.4, GraXpert.

---

## 1. As perguntas, fixadas antes da medição

1. **Que texto cada operação tonal do Siril 1.4.4 grava no HISTORY.** Fecha ou
   refuta, para o Siril, as entradas SUPOSTO do `STRETCH_HISTORY`, e mede as
   operações que não têm entrada nenhuma: log, CLAHE, DDP, PixelMath e a
   ferramenta de curvas do 1.4 (a primeira base medida para a entrada `curves`).
2. **O silêncio do Siril 1.4.4 tem autoridade?** A §3.1 da
   `investigacao-regra-linear.md` exige minúcia *naquela operação*; aqui a
   pergunta é feita operação por operação.
3. **O catálogo casa em operação que preserva a classe?** Controles negativos.
4. **O que o Siril faz com as chaves de escritor que já estão no arquivo**
   (`PROGRAM`, `CREATOR`, `SWCREATE`, `SWMODIFY`) e com `DATAMAX`.
5. **Um segundo programa preserva o carimbo do Siril sem se declarar? E o
   esticamento feito por ele se declara?** GraXpert, parte C.
6. **Item 3, de brinde:** a representação que cada escritor grava — `BITPIX`,
   `BZERO`, `BSCALE`, faixa física.

**O que esta medição NÃO responde:** a população (a porta da estatística de forma,
§8.5 da investigação), o falso positivo de `curves` em arquivos do mundo,
escritores que você não tem, versões não medidas, entrada mono, entrada inteira
de 16 bits.

---

## 2. Por que pixel sintético serve aqui (e não serviu na meia escala)

A evidência desta medição é **o texto que o programa escreve**, e quem decide
esse texto é o programa. Quem escreveu a entrada não consegue fazer a medição
confirmar nada — ao contrário do `fixture-nonlinear`, cujo HISTORY foi escrito
à mão para casar com o que se acreditava (§3.1 e §8.2 da investigação). A lição
da meia escala vale para *estatística de pixel*; comportamento de escritor não
depende da população.

E a classe de cada saída não é suposta pelo nome da operação: o leitor mede a
relação pixel a pixel com a referência.

- `1 − r²` é zero para qualquer transformação afim e cresce com a curvatura;
- `ρ` de Spearman é 1 para qualquer curva monótona ponto a ponto e cai para
  operação local (CLAHE, DDP);
- as duas são invariantes a ganho e offset nos dois lados — a exigência da §8.1.

Nenhum limiar. O relatório imprime a razão de `1 − r²` contra o controle afim —
a conta feita, não os dois lados para o leitor subtrair.

**A entrada.** 512 × 384 RGB, float32 em [0,1], linear por construção: fundo com
dominante de cor e gradiente, um objeto extenso, 160 estrelas, ruído com
variância afim no sinal, nada cortado (máximo 0,87, mínimo 0,0032). Semente
fixa, `RandomState` (fluxo congelado). Duas versões com os mesmos pixels:

- `entrada.fit` traz `PROGRAM`, `CREATOR`, `SWCREATE` e `SWMODIFY` com valores
  que se anunciam sintéticos e não imitam nenhum programa, mais `DATAMAX`, um
  HISTORY e um COMMENT;
- `entrada-limpa.fit` traz só as chaves estruturais.

**Escopo do que for medido:** Siril 1.4.4, Windows, entrada RGB float32, estes
parâmetros. Conclusão mais larga que isso é suposição.

---

## 3. O ensaio: a parte A rodada no Siril 1.2.1

O script roda inteiro no `siril-cli` 1.2.1 (pacote do Ubuntu 24.04). **Tudo
nesta seção é MEDIDO no Siril 1.2.1, pelo chat — e nada dela vale para o
1.4.4.** Vale por si para arquivos salvos pelo 1.2.x, que existem no mundo, e
mostra que o protocolo separa todos os casos que promete separar: houve
operação declarada e reconhecida, declarada e não reconhecida, muda, e controle
que falhou.

| saída | HISTORY que o Siril 1.2.1 gravou | catálogo |
|---|---|---|
| `s01-mtf` | `Midtones transfer (0.003, 0.0123, 1.000)` | Midtones transfer |
| `s02`/`s03-autostretch` | `Autostretch (shadows: -2.80, target bg: 0.25, unlinked)` / `linked` | Autostretch |
| `s04`/`s05-asinh` | `Asinh stretch (amount: 150.0, offset: 0.0, human: no)` / `yes` | Asinh stretch |
| `s06-ght` | `GHS (pivot: 0.004, amount: 53.60, local: 6.0 [0.00, 1.00])` | GHS |
| `s07-autoghs` | `AutoGHS (linked, k.sigma: 0.00, amount: 147.41, local: 13.0 [0.00, 0.70]` e `)` num segundo cartão | **nada** |
| `s08-modasinh` | `GHS asinh (pivot: 0.004, amount: 53.60 [0.00, 1.00])` | **Asinh stretch + GHS** |
| `s09-log`, `s10-clahe`, `s11-pixelmath` | **nenhuma linha** — mudam os pixels (`1 − r²` de 0,0084 a 0,18) | — |
| `s20-linstretch-controle` | `GHS BP shift (new BP: 0.001)` — operação afim, `1 − r²` = 1,6e-15 | **GHS: falso positivo** |
| `s21-subsky-controle` | nenhuma linha | nada (ok) |
| `s30-satu` | `Color saturation 50%, threshold 1.00` | nada |

O que isso já mostra, sempre para o 1.2.1:

**Falso positivo no controle.** `\bGHS\b` casa em `GHS BP shift`, que é
esticamento linear. Hoje o custo é trocar o limiar de 0,05 por 0,02, numa janela
estreita. **Depois do item 2 o HISTORY decide sozinho — e o mesmo falso positivo
vira veredito.** Regra de ordem: nenhuma versão do item 2 entra antes deste
falso positivo estar fechado, com o `s20` como fixture.

**Não reconhecida.** Em `AutoGHS` não há fronteira de palavra antes de `GHS`,
então `\bGHS\b` não casa.

**Dupla contagem.** A linha do `modasinh` recebe dois rótulos, e a entrada
`modasinh|autostretch` nunca casa nela, porque o texto é `GHS asinh`. Proposta:
um rótulo por linha — a primeira regra que casa numa linha fica com ela.

**A entrada 1 (`autostretch`) está REFUTADA só para o modo de visualização**
(medido no 1.4.4, já registrado). O comando grava `Autostretch (...)` no 1.2.1.
O comando e o botão do diálogo ainda precisam ser medidos no 1.4.4.

**Três operações tonais mudas:** log, CLAHE e PixelMath. A autoridade estrita
do silêncio do Siril 1.2.1 é **não**.

**O parâmetro declarado não reproduz a operação.** O offset 0,001 do asinh sai
como `offset: 0.0` — e foi aplicado: com e sem offset, as medianas saem 0,1085
e 0,1299, e o HISTORY é o mesmo. O pivô 0,0045 do GHS sai `0.004`. É a mesma
família do arredondamento de três casas: a declaração serve para dizer *que*
houve esticamento, nunca para reconstruir *qual*.

**O Siril corta o HISTORY em 72 caracteres, sem respeitar palavra:** o `)` do
AutoGHS foi para um segundo cartão. Todos os termos do catálogo vistos até aqui
estão no começo da linha, então o corte não os alcança; uma regex aplicada
cartão a cartão perderia um termo cortado ao meio.

**O carimbo.** Ao salvar, o Siril 1.2.1:

- **sobrescreve** `PROGRAM` com `'Siril v1.2.1'` (comentário *Software that
  created this HDU*);
- **apaga** `SWCREATE`, `CREATOR`, `SWMODIFY`, `DATAMAX` e o COMMENT alheio;
- **preserva** o HISTORY alheio;
- acrescenta `DATE`, `XBINNING`, `YBINNING`, e `BZERO 0` / `BSCALE 1` em dado
  float.

Os pixels saem idênticos. Consequência: no 1.2.1, "dois escritores" não
sobrevive a um carregar-e-salvar — e o arquivo real do 1.4.4 tinha `CREATOR`
nomeando a captura. Ou o 1.4.4 mudou, ou o caminho do empilhamento é outro. O
`s00-base` do 1.4.4 decide.

**`set16bits` não muda o `save`** de uma imagem float carregada: a saída continuou
`BITPIX -32`. Saiu do script; a representação em 16 bits fica para o diálogo,
se ele oferecer (parte B, opcional).

Reproduzível: `apt install siril` (1.2.1-1build3) num Ubuntu 24.04 e os três
arquivos deste protocolo. Só o `DATE` muda entre rodadas.

---

## 4. Procedimento

### Passo 1 — a pasta e a entrada

Da raiz do repositório, no PowerShell:

```
mkdir "D:\justyear image s2\medicao-escritores"
python medicao_escritores.py gera "D:\justyear image s2\medicao-escritores"
copy medicao-escritores.ssf "D:\justyear image s2\medicao-escritores\"
```

O `gera` imprime o SHA-256 das duas entradas e grava tudo em `entrada.json`.

A pasta deve conter **só** os arquivos desta medição. O leitor tem lista de
permissão de nomes (§5): um FITS com outro nome não é aberto e entra no
relatório só como contagem — testado no chat com dois arquivos-isca, zero
vazamento no texto, no JSON e no console. Mas a regra é não deixar nada lá.

Crie também `anotacoes.txt` na pasta, para o que o passo 5 pede.

### Passo 2 — parte A, comandos

```
cd "D:\justyear image s2\medicao-escritores"
& "C:\Program Files\Siril\bin\siril-cli.exe" -d . -s medicao-escritores.ssf
```

Se o `siril-cli.exe` não estiver nesse caminho, procure na pasta de instalação
do Siril. Alternativa pela interface: acrescente a pasta da medição às pastas de
scripts nas Preferências; o script aparece no menu Scripts.

O script começa com `set32bits`, que é o padrão do Siril; se você trabalha
forçando 16 bits, volte a preferência depois. Se ele parar num comando, anote a
linha e a mensagem, ponha `#` na frente dela e rode de novo. Comando que mudou de
sintaxe no 1.4.4 também é medição.

### Passo 3 — parte B, diálogos (Siril 1.4.4, interface)

Com o diretório de trabalho na pasta da medição. Em cada linha: abrir
`s00-base.fit`, aplicar **só** a operação, **Salvar como** com o nome da tabela.
Se o Siril perguntar algo sobre perfil ICC ao abrir, aceite o padrão e anote a
pergunta.

| nome | operação | parâmetros |
|---|---|---|
| `g01-ht-manual` | Histogram Transformation, valores digitados | lo 0.0030, mid 0.0123, hi 1 |
| `g02-ht-botao-auto` | Histogram Transformation: botão de auto-stretch, depois Apply | os que o botão puser |
| `g03-asinh-dialogo` | Asinh Transformation | stretch 150, black point 0 |
| `g04-ghs-dialogo` | Generalised Hyperbolic Stretch, tipo GHS | D 4, b 6, SP 0.0045 |
| `g05-modasinh-dialogo` | o mesmo diálogo, tipo modified arcsinh | D 4, SP 0.0045 |
| `g06-curvas` | Curves Transformation | um ponto no meio, puxado para cima |
| `g07-ddp-digitado` | na linha de comando do Siril: `ddp 0.005 1 1` | — |
| `g08-clahe-dialogo` | CLAHE | clip 2, tiles 8 |
| `g09-pixelmath-dialogo` | PixelMath, com `s00-base` na lista de imagens | `NOME^0.5`, com o nome que o diálogo der a ela |
| `g20-ghs-linear-controle` | Generalised Hyperbolic Stretch, tipo linear / BP shift | BP 0.0010 |

Opcionais: `g30-bge-integrado` (a interface do GraXpert dentro do Siril
1.4, extração de fundo) e `g31-base-16bits` (se o Salvar como oferecer 16 bits
para FITS: o `s00-base` salvo assim).

Notas: o diálogo de histograma arredonda para três casas (já registrado) —
anote o que ele mostrou. O `ddp` vai digitado porque, no 1.2.1, a ajuda do
próprio comando diz que ele não roda em script.

### Passo 4 — parte C, a cadeia com o GraXpert

| nome | como |
|---|---|
| `c00-bge-entrada` | GraXpert: abrir `entrada.fit`, extração de fundo por IA, **Save Processed**, FITS 32 bits |
| `c01-bge` | o mesmo, abrindo `s00-base.fit` |
| `c02-bge-esticado` | no mesmo GraXpert aberto do `c01`, com um esticamento de exibição escolhido: **Save Stretched & Processed**, FITS 32 bits |
| `c03-bge-resalvo` | no Siril, linha de comando: `load c01-bge` e depois `save c03-bge-resalvo` |

O GraXpert pode acrescentar um sufixo ao nome: renomeie para o da tabela. Se um
botão tiver outro nome na sua versão, use o equivalente e anote. Se ele virar a
imagem, o leitor detecta a orientação sozinho e reporta — isso também é
medição.

### Passo 5 — o que anotar à mão (`anotacoes.txt`)

- a versão exata do Siril e do GraXpert, como aparece no Sobre;
- o caminho de menu de cada ferramenta da parte B, e os nomes dos campos quando
  forem outros;
- o que o Salvar como ofereceu;
- qualquer pergunta que apareceu, e qualquer comando que parou o script.

### Passo 6 — ler

```
python medicao_escritores.py le "D:\justyear image s2\medicao-escritores"
```

Escreve `relatorio-medicao.txt` e `relatorio-medicao.json` na pasta. Leia as
linhas com `!!`: são linhas novas que parecem trazer caminho ou nome de arquivo.
Nenhuma deveria aparecer, porque a entrada é sintética.

Traga o `.txt` e o `anotacoes.txt` para o chat. Os `.fit` ficam na pasta até o
Claude Code escolher os fixtures.

---

## 5. Tabela de nomes (é a lista de permissão do leitor)

| prefixo | referência | papel |
|---|---|---|
| `s00` | `entrada` | base |
| `s00b` | `entrada-limpa` | base |
| `s01`–`s11`, `g01`–`g09` | `s00-base` | tonal |
| `s20`, `s21`, `g20` | `s00-base` | controle |
| `s30`, `g30`, `g31` | `s00-base` | informativo |
| `c00` | `entrada` | cadeia |
| `c01`, `c02` | `s00-base` | cadeia |
| `c03` | `c01` | cadeia |

Nome fora deste formato não é aberto.

---

## 6. Regras pré-registradas: o que cada resultado decide

### Por operação tonal

| veredito | consequência |
|---|---|
| DECLARADA E RECONHECIDA | a entrada vira MEDIDO para o Siril 1.4.4, com o texto exato |
| DECLARADA, CATÁLOGO NÃO RECONHECE | entrada nova, derivada do texto observado — e os controles rodam de novo contra ela antes de ela entrar |
| MUDA | a operação entra na lista do que o silêncio do Siril 1.4.4 não cobre |
| INVÁLIDA (pixels idênticos) | a operação não rodou: refazer, não concluir |

A mesma operação por comando e por diálogo pode gravar textos diferentes; os
dois têm que ser reconhecidos.

### Controles

Qualquer rótulo casando num controle é falha do catálogo. O controle vira o
fixture que prova o conserto, e o item 2 não entra antes dele.

### A autoridade do silêncio — decidir antes de ler o relatório do 1.4.4

Três condições, todas medidas: (a) todo texto que o Siril 1.4.4 declara é
reconhecido pelo catálogo, depois das entradas novas; (b) nenhum controle casa;
(c) a lista de operações mudas é conhecida.

Quando (c) não for vazia, há duas políticas:

- **Estrita.** Qualquer operação muda tira a autoridade. O silêncio do Siril
  não decide nada, e a mediana segue decidindo arquivos do Siril.
- **Com cobertura declarada — a proposta.** O silêncio decide "linear", e o log
  diz o que ele não cobre. Algo como: *"Nothing in this Siril 1.4.4 header
  declares a stretch, and Siril declares N of the M tone operations measured.
  Treated as linear — unless [mute operations] were applied, or another program
  stretched this image before Siril last saved it; none of those leaves a trace
  in the header."* A contradição header × pixels continua rodando, como já
  decidido.

A proposta, pelo caso do `ceuclaro`: com a estrita, um empilhamento de céu
claro salvo pelo Siril seria decidido pela mediana — a mesma que erra no
`ceuclaro` — mesmo com um escritor que se identifica e declara quase tudo. A
cobertura declarada usa a informação que existe e diz exatamente onde ela
acaba; é a mesma forma de *"declarar, não recusar"*. **O que é SUPOSTO nela:**
que as operações mudas são raras no esticamento principal. Ela não depende
disso para ser honesta, só para ser útil.

A autoridade vale para a string de versão medida (o `PROGRAM` que o 1.4.4
gravar). Outra versão é escritor desconhecido até ser medida.

**O que nenhuma política resolve:** o silêncio do Siril cobre o que o Siril fez.
No 1.2.1 ele apaga as chaves de escritor alheias ao salvar; se um programa
esticar sem HISTORY e o Siril salvar depois, o header não tem como saber. A
parte C mede se esse caminho existe com o GraXpert.

### Cadeias

| resultado | consequência |
|---|---|
| `c01`/`c02` mantêm `PROGRAM = 'Siril…'` e não acrescentam identificador próprio | o último escritor é invisível: a autoridade do Siril leva a ressalva no log, sempre |
| o GraXpert acrescenta identificador próprio e o `c03` o mantém | a regra pode recusar a autoridade quando houver marca de outro escritor ao lado do `PROGRAM` do Siril |
| o `c03` apaga a marca do GraXpert | a ressalva do log é a única defesa no header; a contradição com os pixels é a outra |
| `c02` esticado sem declaração nova | o caso perigoso existe, MEDIDO: arquivo esticado que parece salvo pelo Siril sem esticamento declarado |

### Chaves de escritor e DATAMAX (`s00`, `s00b`)

- Se o 1.4.4 também sobrescrever `PROGRAM`, então `PROGRAM = 'Siril…'` quer
  dizer "o Siril salvou por último".
- Se preservar `CREATOR`/`SWCREATE`, a pista dos dois escritores ganha o
  primeiro dado MEDIDO para o Siril. Se apagar, ela depende do caminho
  (empilhamento contra carregar-e-salvar).
- `DATAMAX` preservado e desatualizado depois de uma operação (o leitor compara)
  é aviso para a escada da escala: não confiar em `DATAMAX` de arquivo do Siril.

### Formato (item 3)

`BITPIX`, `BZERO`, `BSCALE` e a faixa física de cada saída entram na tabela de
escritores da `spec-escala-decisao.md`, como MEDIDO para o Siril 1.4.4 e o
GraXpert.

---

## 7. O que o Claude Code faz com o relatório

1. Registra no NOTAS os resultados do 1.2.1 (§3) e do 1.4.4, cada linha com
   procedência e versão.
2. Atualiza os comentários de procedência do `STRETCH_HISTORY` sem mudar regex
   antes do relatório do 1.4.4 — com uma exceção de ordem: o falso positivo do
   `GHS BP shift` fecha antes de qualquer versão do item 2.
3. Escolhe os fixtures (§8) e registra cada um no MANIFEST.
4. Se o `STRETCH_HISTORY` mudar, atualiza a cópia em `medicao_escritores.py`; o
   comentário dela diz de onde veio.

---

## 8. Fixtures

As saídas são pixels sintéticos deste gerador mais o header que o programa
escreveu. Nenhum dado de terceiro. Candidatas, uma por ramo:

| fixture | o que dispara |
|---|---|
| uma saída por entrada do catálogo que o 1.4.4 confirmar | o rótulo esperado |
| `s20` e `g20` | nenhum rótulo — é o fixture do conserto do falso positivo |
| `s00-base` | o silêncio de escritor conhecido (o ramo novo do item 2) |
| uma muda (ex.: `s09-log`) | esticado e mudo: a contradição header × pixels |
| `c02` ou `c03` | o último escritor invisível |

**Nome de arquivo descreve o ramo, não o programa:** `fixture-escritor-mtf.fit`,
`fixture-escritor-controle-bp.fit`, e assim por diante. Programa, versão e
sistema vão na procedência do MANIFEST, que é onde a informação serve. Hoje
nenhum nome de arquivo do repositório tem nome de programa de terceiro, com uma
exceção: `fixture-seestar` e seus cinco goldens.

Cada arquivo tem 2,36 MB, na ordem dos fixtures atuais. Procedência no MANIFEST:
header MEDIDO (programa, versão, sistema), pixels de `medicao_escritores.py`, semente
20260923, SHA-256 do arquivo.
