# A02 deimantų duomenų rinkinio analizė

Šiame projekte atliekama pirminė A02 duomenų rinkinio analizė ir paruošimas tolimesniam tyrimui.

## Duomenų rinkinys

A02 duomenys aprašo realius apvaliai šlifuotus deimantus.

- Objektų skaičius: **4000**
- Stulpelių skaičius: **20**
- Skaitinių požymių skaičius: **19**
- Kategorinis požymis: `class`
- Klasės: **Ideal** ir **Premium**

Bazinė duomenų aibė: `ggplot2::diamonds`.

Pagrindiniai požymiai:

- `carat` – deimanto masė;
- `depth`, `table` – deimanto proporcijų rodikliai;
- `price` – kaina;
- `x`, `y`, `z` – geometriniai matmenys;
- `volume_xyz`, `area_xy`, `area_xz`, `area_yz`, `mean_dimension` – išvestiniai dydžio rodikliai;
- `price_per_carat`, `length_width_ratio`, `depth_ratio`, `table_depth_ratio`, `carat_per_volume`, `price_per_volume`, `dimension_cv` – išvestiniai santykiniai rodikliai.

---

## 1. Duomenų nuskaitymas ir struktūros patikra

Duomenys nuskaitomi iš `A02.csv`:

```r
library(ggplot2)

deimantai <- read.csv("A02.csv", na.strings = c(""))

head(deimantai, 3)
str(deimantai)
dim(deimantai)

deimantai_original <- deimantai
```

Pradinė patikra parodė, kad duomenų rinkinyje yra **4000 eilučių ir 20 stulpelių**.

---

## 2. Duomenų tipų ir formato tvarkymas

### `price`

`price` buvo nuskaitytas kaip tekstinis stulpelis, nes reikšmėse yra valiutos simbolis, pavyzdžiui:

```text
3326 €
```

Todėl pašalinti visi nereikalingi simboliai ir reikšmės paverstos į skaitinį tipą:

```r
deimantai$price <- gsub("[^0-9.]", "", deimantai$price)
deimantai$price <- as.numeric(as.character(deimantai$price))
```

### `depth`

`depth` iš pradžių taip pat buvo tekstinio tipo, todėl paverstas į skaitinį:

```r
deimantai$depth <- suppressWarnings(as.numeric(deimantai$depth))
```

Netinkamos tekstinės reikšmės konvertavimo metu pavirto į `NA`.

### `class`

Klasės požymis paverstas kategoriniu:

```r
deimantai$class <- as.factor(deimantai$class)

str(deimantai$class)
```

Gauti du lygiai:

- `Ideal`
- `Premium`

---

## 3. Trūkstamų reikšmių analizė

Naudotas kodas:

```r
colSums(is.na(deimantai))

round(colMeans(is.na(deimantai)) * 100, 2)

sum(!complete.cases(deimantai))

round(mean(!complete.cases(deimantai)) * 100, 2)
```

Gauti rezultatai:

| Požymis | Trūkstamų reikšmių skaičius | Procentas |
|---|---:|---:|
| `carat` | 60 | 1.50 % |
| `depth` | 40 | 1.00 % |
| `price` | 60 | 1.50 % |
| `volume_xyz` | 60 | 1.50 % |
| `carat_per_volume` | 3 | 0.07 % |
| `price_per_volume` | 3 | 0.07 % |

Kituose požymiuose trūkstamų reikšmių nenustatyta.

Bent vieną trūkstamą reikšmę turi:

- **217 eilučių**
- **5.42 % visų objektų**

Trūkstamų reikšmių pasiskirtymas pagal klasę(procentais):

| Požymis | Ideal | Premium |
|---|---:|---:|
| `carat` | 1.50 % | 1.50 % |
| `depth` | 0.90 % | 1.10 % |
| `price` | 1.50 % | 1.50 % |
| `volume_xyz` | 1.60 % | 1.40 % |
| `carat_per_volume` | 0.05 % | 0.10 % |
| `price_per_volume` | 0.05 % | 0.10 % |

### Išvada

Trūkstamų reikšmių kiekis nėra labai didelis, tačiau jos yra keliuose svarbiuose požymiuose. Toliau reikės nuspręsti, kokį jų apdorojimo būdą pasirinkti. Trūkstamų reikšmių pasiskirstymas tarp Ideal ir Premium klasių yra beveik vienodas, reikšmingų skirtumų nenustatyta.

---

## 4. Dublikatų patikra

Naudotas kodas:

```r
sum(duplicated(deimantai))

deimantai[duplicated(deimantai), ]
```

Rezultatas:

```text
0
```

Duomenų rinkinyje **pilnų dublikatų nėra**.

---

## 5. Klasių balanso tikrinimas

Naudotas kodas:

```r
table(deimantai$class)

round(prop.table(table(deimantai$class)) * 100, 2)
```

Rezultatai:

| Klasė | Objektų skaičius | Procentas |
|---|---:|---:|
| Ideal | 2000 | 50 % |
| Premium | 2000 | 50 % |

### Išvada

Klasių disbalanso problema nenustatyta. Abi klasės sudaro po **50 %** visų objektų.

---

## 6. Nelogiškų reikšmių tikrinimas

Kadangi analizuojami realūs deimantai, kai kurie fiziniai dydžiai negali būti neigiami arba lygūs nuliui.

Naudotas kodas:

```r
sum(deimantai$carat <= 0, na.rm = TRUE)

sum(deimantai$price <= 0, na.rm = TRUE)

sum(deimantai$x <= 0, na.rm = TRUE)
sum(deimantai$y <= 0, na.rm = TRUE)
sum(deimantai$z <= 0, na.rm = TRUE)

sum(deimantai$depth <= 0, na.rm = TRUE)
sum(deimantai$table <= 0, na.rm = TRUE)
```

Rezultatai:

| Sąlyga | Reikšmių skaičius |
|---|---:|
| `carat <= 0` | 14 |
| `price <= 0` | 0 |
| `x <= 0` | 0 |
| `y <= 0` | 13 |
| `z <= 0` | 3 |
| `depth <= 0` | 0 |
| `table <= 0` | 0 |

---

## 7. Probleminių objektų nustatymas

Kadangi kai kuriuose požymiuose yra `NA`, probleminėms eilutėms išrinkti naudojamas `which()`:

```r
problemines <- deimantai[
  which(
    deimantai$carat <= 0 |
      deimantai$y <= 0 |
      deimantai$z <= 0
  ),
]

nrow(problemines)
```

Rezultatas:

```text
30
```

Taigi **30 unikalių objektų** turi bent vieną aiškiai nelogišką reikšmę.

Tai sudaro:

```r
30 / 4000 * 100
```

```text
0.75 %
```

### Išvada

**0.75 % visų objektų** turi bent vieną fiziškai nelogišką `carat`, `y` arba `z` reikšmę.

Šios reikšmės neturėtų būti automatiškai pašalintos neįvertinus jų kilmės ir poveikio kitiems požymiams.

---

## 8. Konkrečių nelogiškų reikšmių peržiūra

### `carat`

```r
deimantai[
  deimantai$carat <= 0 & !is.na(deimantai$carat),
]
```

Rastos **14 neigiamos `carat` reikšmės**.

### `y`

```r
deimantai[
  deimantai$y <= 0 & !is.na(deimantai$y),
]
```

Rasta **13 neigiamų `y` reikšmių**.

### `z`

```r
deimantai[
  deimantai$z <= 0 & !is.na(deimantai$z),
]
```

Rastos **3 nulinės `z` reikšmės**.

Šiuose objektuose dėl `z = 0` taip pat atsiranda nulinės arba trūkstamos kai kurių išvestinių požymių reikšmės, pavyzdžiui:

- `volume_xyz = 0`
- `area_xz = 0`
- `area_yz = 0`
- `depth_ratio = 0`
- `carat_per_volume = NA`
- `price_per_volume = NA`

---

## 9. Pirminė aprašomoji statistika

Naudotas kodas:

```r
summary(deimantai)
```

Pirminė statistika parodė, kad kai kuriuose požymiuose gali būti labai nutolusių reikšmių.

Pavyzdžiui, `depth`:

- mediana: apie **61.7**
- 3 kvartilis: apie **62.2**
- maksimali reikšmė: **239.06**

Tai rodo, kad `depth` turi bent vieną labai neįprastą reikšmę, kurią reikės toliau tirti kaip galimą išskirtį.

---

## 10. Požymių pasiskirstymo ir išskirčių analizė

Siekiant įvertinti skaitinių požymių pasiskirstymą ir nustatyti galimas statistines išskirtis, kiekvienam skaitiniam požymiui buvo sudaryta atskira histograma ir boxplot diagrama.

### Histogramų sudarymas

Histogramos leidžia įvertinti kiekvieno požymio pasiskirstymo formą, reikšmių koncentraciją ir galimas nuo pagrindinės reikšmių dalies nutolusias reikšmes.

Histogramos parodė, kad skirtingų požymių pasiskirstymai nėra vienodi. Kai kuriuose požymiuose matomos labiau nuo pagrindinės reikšmių dalies nutolusios reikšmės, kurios gali būti laikomos galimomis statistinėmis išskirtimis. Ypač tai pastebima `price`, `price_per_carat`, `price_per_volume`, `depth` ir `volume_xyz` požymiuose.

### Išskirčių nustatymas

Statistinės išskirtys buvo nustatomos naudojant **1.5 × IQR taisyklę**.

Apatinė ir viršutinė išskirčių ribos apskaičiuojamos taip:

```text
Apatinė riba = Q1 - 1.5 × IQR
Viršutinė riba = Q3 + 1.5 × IQR
```

Reikšmės, esančios už šių ribų, laikomos statistinėmis išskirtimis.

Išskirčių procentas skaičiuojamas nuo kiekvieno požymio galiojančių, t. y. ne-`NA`, reikšmių skaičiaus.

Gauti rezultatai:

| Požymis | Išskirčių skaičius | Procentas |
|---|---:|---:|
| `price` | 295 | 7.49 % |
| `price_per_carat` | 146 | 3.65 % |
| `price_per_volume` | 136 | 3.40 % |
| `dimension_cv` | 116 | 2.90 % |
| `volume_xyz` | 114 | 2.89 % |
| `depth_ratio` | 114 | 2.85 % |
| `depth` | 98 | 2.47 % |
| `carat` | 73 | 1.85 % |
| `carat_per_volume` | 62 | 1.55 % |
| `table_depth_ratio` | 34 | 0.85 % |
| `y` | 15 | 0.38 % |
| `area_xy` | 10 | 0.25 % |
| `area_xz` | 8 | 0.20 % |
| `area_yz` | 7 | 0.18 % |
| `z` | 6 | 0.15 % |
| `length_width_ratio` | 4 | 0.10 % |
| `x` | 2 | 0.05 % |
| `mean_dimension` | 2 | 0.05 % |
| `table` | 1 | 0.03 % |

### Išvada

Pagal **1.5 × IQR taisyklę** daugiausia statistinių išskirčių nustatyta `price` požymyje – **295 reikšmės (7.49 % galiojančių `price` reikšmių)**.

Santykinai daugiau išskirčių taip pat nustatyta `price_per_carat` (3.65 %), `price_per_volume` (3.40 %), `dimension_cv` (2.90 %), `volume_xyz` (2.89 %), `depth_ratio` (2.85 %) ir `depth` (2.47 %) požymiuose.

Svarbu pažymėti, kad pagal IQR taisyklę nustatytos statistinės išskirtys nebūtinai yra klaidingos reikšmės. Jos gali atspindėti realius, retesnius deimantus, todėl prieš sprendžiant dėl jų šalinimo ar koregavimo būtina įvertinti jų fizinę prasmę, pasiskirstymą ir ryšį su kitais požymiais.

Fiziškai nelogiškos reikšmės, tokios kaip neigiamas `carat`, neigiamas `y` ar `z = 0`, vertinamos atskirai nuo statistinių išskirčių.




# Tolimesni analizės žingsniai

Toliau planuojama:

1. tirti požymių pasiskirstymus naudojant histogramas; +
2. aptikti galimas išskirtis naudojant boxplot diagramas;+
3. įvertinti išskirčių skaičių ir jų poveikį; +-
4. palyginti `Ideal` ir `Premium` klases;
5. tirti ryšius tarp:
   - `carat` ir `price`;
   - `volume_xyz` ir `price`;
   - `carat` ir `volume_xyz`;
6. atlikti koreliacijų analizę;
7. nustatyti stipriai tarpusavyje susijusius bazinius ir išvestinius požymius;
8. pasirinkti tinkamus trūkstamų ir nelogiškų reikšmių apdorojimo būdus;
9. įvertinti, ar duomenų rinkinys tinkamas tolimesnei analizei.

[README.md](https://github.com/user-attachments/files/32465561/README.md)
