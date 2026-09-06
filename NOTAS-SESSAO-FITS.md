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
