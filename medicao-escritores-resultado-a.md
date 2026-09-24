# Resultado da parte A (Siril 1.4.4) e o que muda no catálogo

*2026-09-24. Parte A de `medicao-escritores.md`, rodada por quem conduz no Siril
1.4.4 (Windows, `siril-cli`). A entrada é idêntica, byte a byte, à do ensaio no
1.2.1 (SHA-256 `31cdd423…` e `be3b6774…`): toda diferença entre os dois
relatórios é do Siril, não da entrada. Relatório bruto:
`D:\justyear image s2\medicao-escritores\relatorio-medicao.txt`.*

---

## 0. Decisão registrada antes de ler este relatório

**Política da autoridade do silêncio: com cobertura declarada**
(`medicao-escritores.md`, §6). Decidida por quem conduz depois de a parte A
rodar e antes de o relatório ser gerado.

---

## 1. O que o Siril 1.4.4 gravou — MEDIDO, operações por comando

| operação | HISTORY no 1.4.4 | igual ao 1.2.1? | catálogo |
|---|---|---|---|
| `mtf` | `Midtones transfer (0.003, 0.0123, 1.000)` | sim | Midtones transfer |
| `autostretch` | `Autostretch (shadows: -2.80, target bg: 0.25, unlinked)` / `linked` | sim | Autostretch |
| `asinh` | `Asinh stretch (amount: 150.0, offset: 0.0, human: no)` / `yes` | sim — o offset 0.001 sai `0.0` nas duas | Asinh stretch |
| `ght` | `GHS (pivot: 0.004, amount: 53.60, local: 6.0 [0.00, 1.00])` | sim | GHS |
| `autoghs` | `AutoGHS (linked, k.sigma: 0.00, amount: 5.00, local: 13.0 [0.00, 0.70])` | **não** (§2) | **nada** |
| `modasinh` | `GHS asinh (pivot: 0.004, amount: 53.60 [0.00, 1.00])` | sim | **Asinh stretch + GHS** |
| `log`, `clahe`, `pm` | nenhuma linha | sim | — |
| `linstretch` (controle) | `GHS BP shift (new BP: 0.001)` | sim | **GHS: falso positivo** |
| `subsky` (controle) | nenhuma linha | sim | nada (ok) |
| `satu` (informativo) | `Color saturation 50%, threshold 1.00` | sim | nada |

**Cobertura, só comandos:** 8 de 11 operações tonais declaram. Mudas: log, CLAHE
e PixelMath. Diálogos (parte B) e cadeia (parte C) ainda não medidos — nada se
conclui sobre eles.

---

## 2. O que mudou do 1.2.1 para o 1.4.4 — MEDIDO nas duas

**A string do escritor.** `PROGRAM = 'Siril v1.2.1'` virou `'Siril 1.4.4'`, sem
o `v`. Quem identificar o escritor por texto tem que aceitar as duas formas.

**O carimbo.** Ao carregar e salvar, o 1.4.4 **preserva** `CREATOR`, `SWMODIFY`
e o COMMENT alheio, e **apaga** `SWCREATE` e `DATAMAX`. O 1.2.1 apagava os quatro
e o COMMENT. O 1.4.4 acrescenta `MIPS-FLO` e `DATE`; o 1.2.1, `DATE`, `XBINNING`
e `YBINNING`. HISTORY alheio: as duas preservam.

Consequências:

- **A pista dos dois escritores é comportamento do Siril 1.4.4** — `CREATOR`
  nomeia a captura, `PROGRAM` nomeia quem salvou. MEDIDO num caminho só
  (carregar e salvar). Captura que se identifica por `SWCREATE` (o N.I.N.A., no
  exemplo público) **perde a identidade** ao passar pelo Siril 1.4.4; por
  `CREATOR` (o ASIAIR), mantém.
- **`SWMODIFY` herdado sobrevive, e o Siril não acrescenta o seu.** Num arquivo
  salvo pelo Siril, `SWMODIFY` não é "o último a modificar". A leitura da
  SBFITSEXT (último `SWMODIFY` = último modificador) só vale quando o último
  escritor segue a SBFITSEXT.
- **`DATAMAX`:** as duas versões apagam. Arquivo que passou pelo Siril não traz
  `DATAMAX` desatualizado — não traz nenhum.

**O `autoghs` mudou de sentido.** Os mesmos argumentos (`autoghs -linked 0 5`)
esticam bem menos no 1.4.4: mediana do canal 0 de 0,298 para 0,075, `1 − r²` de
0,812 para 0,386. O HISTORY declara `amount: 5.00` no 1.4.4 contra `147.41`
(= e⁵ − 1) no 1.2.1. MEDIDO: o efeito. SUPOSTO: que o segundo argumento passou
de D para amount. Para o `confusoes.md`: script antigo com `autoghs` dá outro
resultado no 1.4.4, sem erro nenhum. A linha também deixou de ser cortada em
dois cartões — ficou curta o bastante.

---

## 3. O que vale igual nas duas versões, e pesa

**O PixelMath não se declara e apaga o HISTORY herdado.** A linha da entrada
sumiu da saída nas duas versões; no 1.4.4 aparece `STACKCNT = 1`. Não é só uma
operação muda: ela apaga a declaração das operações anteriores. E é o caminho
comum para recombinar as estrelas depois do StarNet — um arquivo esticado e
declarado pode chegar mudo depois dela. O SUPOSTO da política de cobertura
("operações mudas são raras no esticamento principal") não cobre esse caso: o
PixelMath não estica, mas apaga quem esticou.

**Proposta — a confirmar por quem conduz antes do item 2:** o silêncio do Siril
só tem autoridade quando o HISTORY mostra a origem: a linha de empilhamento do
próprio Siril. Forma medida nos dois arquivos reais do Siril 1.4.4:
`mean stacking with winsorized sigma clipping … normalized output …`. Como o
PixelMath apaga tudo, inclusive essa linha, a presença dela prova que a cadeia
desde o empilhamento não foi apagada — mesmo que depois da recombinação outras
operações tenham escrito linhas novas. Sem a linha, o arquivo vai para o caminho
do mudo, com a declaração de hoje. SUPOSTO: a forma da linha para outros
métodos de empilhamento (mediana, soma, outras rejeições) — medir quando houver
um empilhamento de cada.

**Também igual nas duas:** o falso positivo do `GHS BP shift`; o `AutoGHS` não
reconhecido; a dupla contagem do `GHS asinh`; o comando `autostretch` se declara
(o REFUTADO da entrada 1 vale só para o modo de visualização).

---

## 4. Para o Claude Code — agora

**(a) NOTAS.** Registrar §0 a §3, cada linha com procedência, versão e sistema, e
a decisão da política com a data e o momento em que foi tomada.

**(b) `STRETCH_HISTORY`.** Cada mudança com o fixture que a faz disparar:

1. **GHS: não casar em `GHS BP shift`, e casar em `AutoGHS`.** Sugestão:
   `/generalised hyperbolic|generalized hyperbolic|\b(?:auto)?GHS\b(?!\s+BP shift)/i`.
   Fixtures: `s20` não recebe rótulo nenhum; `s06` e `s07` recebem.
2. **Um rótulo por linha.** Cada linha de HISTORY recebe no máximo um rótulo: o
   da primeira regra que casa nela. Entrada nova, MEDIDO, antes das de asinh e
   GHS: `/GHS asinh/i` → `'Modified asinh'`. Fixture: `s08` recebe exatamente um
   rótulo, `Modified asinh`.
3. **A entrada 7 tem o rótulo errado** — casa `modasinh` e rotula `Autostretch`.
   Vira `/modasinh/i` → `'Modified asinh'`, SUPOSTO: nenhuma versão medida
   escreve `modasinh`. A alternativa `|autostretch` sai (código morto, já
   anotado).
4. **Procedência nos comentários.** Entrada 1: REFUTADO para o modo de
   visualização (1.4.4); MEDIDO para o comando (1.2.1 e 1.4.4), com o texto.
   Entradas de asinh, GHS e midtone: MEDIDO nas duas versões, com o texto de
   cada uma.
5. **Controles contra o catálogo novo:** `s20` e `s21` sem rótulo; as mudas
   (`s09`–`s11`) sem rótulo.
6. **A cópia do catálogo em `medicao_escritores.py`** acompanha, e o relatório
   da pasta é regerado com ela: o controle `s20` tem que passar a dar
   `CONTROLE OK`.

**(c) Fixtures**, tirados de `D:\justyear image s2\medicao-escritores\`, com
nome que descreve o ramo (`medicao-escritores.md`, §8):

| origem | fixture | dispara |
|---|---|---|
| `s20` | `fixture-escritor-controle-bp.fit` | nenhum rótulo (o conserto do falso positivo) |
| `s07` | `fixture-escritor-autoghs.fit` | GHS reconhecido |
| `s08` | `fixture-escritor-ghs-asinh.fit` | um rótulo só |
| `s00-base` | `fixture-escritor-base.fit` | silêncio de escritor conhecido (para o item 2) |
| `s11` | `fixture-escritor-pixelmath.fit` | esticado, mudo e com HISTORY apagado (para o item 2) |

MANIFEST: header MEDIDO no Siril 1.4.4 (Windows); pixels de
`medicao_escritores.py`, semente 20260923; SHA-256 do arquivo.

**(d) Evidência no repositório:** copiar o `relatorio-medicao.txt` da pasta da
medição para a raiz como `medicao-escritores-relatorio-a.txt`.

**(e) NÃO fazer ainda: o item 2** (a regra nova da linearidade). Ele espera:

- a parte B — curvas, o botão do histograma, CLAHE e PixelMath por diálogo podem
  mudar a lista das mudas;
- a parte C — o GraXpert decide a ressalva do último escritor;
- a confirmação da condição da linha de empilhamento (§3).

---

## 5. O que falta medir

Parte B (diálogos) e parte C (GraXpert), como em `medicao-escritores.md`.
