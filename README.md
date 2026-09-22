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

# A02 duomenų validavimas pagal originalią `ggplot2::diamonds` bazę

Šio etapo tikslas – patikrinti fiziškai nelogiškas A02 duomenų reikšmes, palyginti jas su originalia `ggplot2::diamonds` duomenų baze ir, kur galima, pagrįstai atkurti sugadintas bazinių požymių reikšmes.

## 1. Kodėl buvo naudojama originali bazė

A02 duomenų rinkinys yra sudarytas iš `ggplot2::diamonds` duomenų bazės. Pirminės duomenų kokybės analizės metu buvo nustatytos fiziškai nelogiškos reikšmės:

- `carat <= 0` – 14 reikšmių;
- `y <= 0` – 13 reikšmių;
- `z <= 0` – 3 reikšmės.

Kadangi šios reikšmės realiam deimantui yra nelogiškos arba abejotinos, buvo nuspręsta patikrinti, ar atitinkamus objektus galima vienareikšmiškai rasti originalioje `ggplot2::diamonds` bazėje.

Svarbu: originali bazė buvo naudojama ne statistinėms išskirtims automatiškai šalinti, o tik konkrečioms fiziškai nelogiškoms A02 reikšmėms validuoti.

---

## 2. Originalios duomenų bazės paruošimas

Originalioje `diamonds` bazėje pjūvio kokybės požymis vadinasi `cut`, o A02 rinkinyje – `class`.

Todėl originalioje bazėje buvo sukurtas `class` stulpelis ir paliktos tik A02 naudojamos klasės `Ideal` ir `Premium`.

```r
library(ggplot2)
library(dplyr)

originalas <- ggplot2::diamonds %>%
  mutate(
    class = as.character(cut)
  ) %>%
  filter(class %in% c("Ideal", "Premium"))
```

Kad būtų galima aiškiai sekti, kuri A02 eilutė tikrinama, kiekvienai eilutei buvo suteiktas identifikatorius:

```r
deimantai_su_id <- deimantai %>%
  mutate(a02_id = row_number())
```

---

## 3. Neigiamų `carat` reikšmių tikrinimas

Kadangi `carat` reikšmės buvo įtariamos kaip sugadintos, jos nebuvo naudojamos ieškant atitikmens originalioje bazėje.

Atitikmuo buvo ieškomas pagal kitus bazinius požymius:

- `depth`;
- `table`;
- `price`;
- `x`;
- `y`;
- `z`;
- `class`.

```r
blogas_carat <- deimantai_su_id %>%
  filter(!is.na(carat) & carat <= 0)

carat_match <- blogas_carat %>%
  select(
    a02_id,
    depth,
    table,
    price,
    x,
    y,
    z,
    class,
    carat_A02 = carat
  ) %>%
  left_join(
    originalas %>%
      select(
        depth,
        table,
        price,
        x,
        y,
        z,
        class,
        carat_original = carat
      ),
    by = c(
      "depth",
      "table",
      "price",
      "x",
      "y",
      "z",
      "class"
    )
  )
```

Kiekvienai iš 14 probleminių `carat` eilučių buvo rastas po vieną aiškų atitikmenį originalioje bazėje.

Pavyzdžiai:

| A02 eilutė | A02 `carat` | Originalus `carat` |
|---:|---:|---:|
| 1 | -0.609 | 0.96 |
| 168 | -0.246 | 0.31 |
| 189 | -1.088 | 0.74 |
| 744 | -1.615 | 1.01 |
| 1992 | -0.279 | 2.00 |
| 2178 | -0.941 | 0.57 |
| 2194 | -1.564 | 0.39 |
| 2195 | -1.826 | 1.11 |
| 2762 | -0.914 | 2.43 |
| 2980 | -2.403 | 0.33 |
| 3566 | -2.074 | 2.01 |
| 3594 | -0.408 | 2.47 |
| 3672 | -1.165 | 0.70 |
| 3994 | -0.154 | 0.51 |

### Išvada

Visos 14 neigiamos `carat` reikšmės buvo patikimai susietos su originaliais `diamonds` įrašais, todėl jas galima pagrįstai atkurti.

---

## 4. Neigiamų `y` reikšmių tikrinimas

Kadangi `y` buvo probleminis požymis, jis nebuvo naudojamas atitikmens paieškoje.

Atitikmens buvo ieškoma pagal:

- `carat`;
- `depth`;
- `table`;
- `price`;
- `x`;
- `z`;
- `class`.

```r
blogas_y <- deimantai_su_id %>%
  filter(!is.na(y) & y <= 0)

y_match <- blogas_y %>%
  select(
    a02_id,
    carat,
    depth,
    table,
    price,
    x,
    z,
    class,
    y_A02 = y
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        depth,
        table,
        price,
        x,
        z,
        class,
        y_original = y
      ),
    by = c(
      "carat",
      "depth",
      "table",
      "price",
      "x",
      "z",
      "class"
    )
  )
```

Visoms 13 probleminių A02 eilučių buvo nustatyta originali teigiama `y` reikšmė.

Vienai A02 eilutei (`a02_id = 3617`) originalioje bazėje buvo rasti du atitikmenys, tačiau abiejuose `y_original` reikšmė buvo vienoda – `4.45`. Todėl ir šiuo atveju atkuriama reikšmė yra vienareikšmė.

Pavyzdžiai:

| A02 eilutė | A02 `y` | Originalus `y` |
|---:|---:|---:|
| 868 | -3.956 | 5.79 |
| 882 | -8.298 | 5.29 |
| 1059 | -1.202 | 5.16 |
| 1291 | -11.309 | 5.12 |
| 1442 | -3.212 | 5.85 |
| 2037 | -7.940 | 5.25 |
| 2126 | -2.038 | 7.28 |
| 2978 | -3.622 | 5.33 |
| 3036 | -9.506 | 5.63 |
| 3149 | -7.323 | 7.68 |
| 3404 | -5.391 | 4.83 |
| 3509 | -11.851 | 5.76 |
| 3617 | -10.711 | 4.45 |

### Išvada

Visos 13 neigiamos `y` reikšmės galėjo būti pagrįstai atkurtos pagal originalią duomenų bazę.

---

## 5. `z = 0` reikšmių tikrinimas

Buvo rastos 3 eilutės, kuriose `z = 0`.

Atitikmens buvo ieškoma pagal:

- `carat`;
- `depth`;
- `table`;
- `price`;
- `x`;
- `y`;
- `class`.

```r
blogas_z <- deimantai_su_id %>%
  filter(!is.na(z) & z <= 0)

z_match <- blogas_z %>%
  select(
    a02_id,
    carat,
    depth,
    table,
    price,
    x,
    y,
    class,
    z_A02 = z
  ) %>%
  left_join(
    originalas %>%
      select(
        carat,
        depth,
        table,
        price,
        x,
        y,
        class,
        z_original = z
      ),
    by = c(
      "carat",
      "depth",
      "table",
      "price",
      "x",
      "y",
      "class"
    )
  )
```

Gauti rezultatai:

| A02 eilutė | A02 `z` | Originalus `z` |
|---:|---:|---:|
| 1061 | 0 | 0 |
| 1492 | 0 | 0 |
| 3658 | 0 | 0 |

### Išvada

Visos 3 `z = 0` reikšmės tokios pačios ir originalioje `ggplot2::diamonds` bazėje.

Todėl jos nelaikomos A02 rinkinio sugadinimo rezultatu ir nebuvo keičiamos. Jos paliekamos kaip originalaus šaltinio probleminės arba fiziškai abejotinos reikšmės.

---

## 6. Patikimai nustatytų reikšmių atkūrimas

Prieš taisant buvo išsaugota duomenų kopija:

```r
deimantai_pries_atkurima <- deimantai
```

### `carat` atkūrimas

```r
for (i in 1:nrow(carat_match)) {
  deimantai$carat[carat_match$a02_id[i]] <-
    carat_match$carat_original[i]
}
```

### `y` atkūrimas

Kadangi viena eilutė turėjo du identišką `y_original` rezultatą duodančius atitikmenis, paliekamas vienas įrašas kiekvienam A02 objektui:

```r
y_match_unique <- y_match %>%
  distinct(a02_id, .keep_all = TRUE)

for (i in 1:nrow(y_match_unique)) {
  deimantai$y[y_match_unique$a02_id[i]] <-
    y_match_unique$y_original[i]
}
```

Po atkūrimo patikrinta:

```r
sum(deimantai$carat <= 0, na.rm = TRUE)
sum(deimantai$y <= 0, na.rm = TRUE)
sum(deimantai$z <= 0, na.rm = TRUE)
```

Rezultatai:

```text
carat <= 0 : 0
y <= 0     : 0
z <= 0     : 3
```

### Išvada

Sėkmingai atkurtos:

- 14 `carat` reikšmių;
- 13 `y` reikšmių.

Iš viso atkurta **27 fiziškai nelogiškos ir pagal originalią bazę vienareikšmiškai identifikuotos reikšmės**.

---

## 7. Išvestinių požymių perskaičiavimas

Kadangi A02 rinkinyje yra daug iš bazinių matavimų apskaičiuotų požymių, po `carat` ir `y` atkūrimo išvestiniai požymiai buvo perskaičiuoti iš naujo.

```r
# Tūris
deimantai$volume_xyz <- deimantai$x * deimantai$y * deimantai$z

# Plotai
deimantai$area_xy <- deimantai$x * deimantai$y
deimantai$area_xz <- deimantai$x * deimantai$z
deimantai$area_yz <- deimantai$y * deimantai$z

# Kaina vienam karatui
deimantai$price_per_carat <- deimantai$price / deimantai$carat

# Ilgio ir pločio santykis
deimantai$length_width_ratio <- deimantai$x / deimantai$y

# Gylio santykis
deimantai$depth_ratio <- deimantai$z / ((deimantai$x + deimantai$y) / 2)

# Table ir depth santykis
deimantai$table_depth_ratio <- deimantai$table / deimantai$depth

# Karatų kiekis tūrio vienetui
deimantai$carat_per_volume <- deimantai$carat / deimantai$volume_xyz

# Kaina tūrio vienetui
deimantai$price_per_volume <- deimantai$price / deimantai$volume_xyz

# Vidutinis matmuo
deimantai$mean_dimension <- (deimantai$x + deimantai$y + deimantai$z) / 3
```

### `dimension_cv`

Matmenų variacijos koeficientas perskaičiuotas naudojant populiacijos standartinį nuokrypį:

```r
deimantai$dimension_cv <- apply(
  deimantai[, c("x", "y", "z")],
  1,
  function(v) {
    m <- mean(v)
    sd_pop <- sqrt(mean((v - m)^2))
    sd_pop / m
  }
)
```

Po šio perskaičiavimo `dimension_cv` reikšmių diapazonas vėl atitiko pradinį A02 duomenų diapazoną.

---

## 8. `Inf` reikšmių tvarkymas

Kadangi trijose eilutėse `z = 0`, šiose eilutėse:

```text
volume_xyz = x * y * z = 0
```

Todėl skaičiuojant:

```text
carat_per_volume = carat / volume_xyz
price_per_volume = price / volume_xyz
```

atsirado `Inf` reikšmės.

Kadangi dalyba iš nulio neturi prasmingos skaitinės interpretacijos, `Inf` reikšmės buvo pakeistos į `NA`:

```r
deimantai$carat_per_volume[
  is.infinite(deimantai$carat_per_volume)
] <- NA

deimantai$price_per_volume[
  is.infinite(deimantai$price_per_volume)
] <- NA
```

Patikrinimas:

```r
sum(is.infinite(as.matrix(
  deimantai[sapply(deimantai, is.numeric)]
)))
```

Rezultatas:

```text
0
```

Taigi galutinėje aibėje `Inf` reikšmių nebeliko.

---

## 9. Trūkstamos reikšmės po perskaičiavimo

Po išvestinių požymių perskaičiavimo gauta:

| Požymis | `NA` skaičius |
|---|---:|
| `carat` | 60 |
| `depth` | 40 |
| `price` | 60 |
| `price_per_carat` | 120 |
| `table_depth_ratio` | 40 |
| `carat_per_volume` | 63 |
| `price_per_volume` | 63 |

Kituose požymiuose `NA` reikšmių nėra.

### Kodėl padidėjo kai kurių išvestinių požymių `NA` skaičius?

`price_per_carat` priklauso nuo `price` ir `carat`, todėl jei bent vienos bazinės reikšmės nėra, negalima apskaičiuoti ir išvestinio rodiklio.

Analogiškai:

- `table_depth_ratio` negali būti apskaičiuotas, jei trūksta `depth`;
- `carat_per_volume` negali būti apskaičiuotas, jei trūksta `carat` arba `volume_xyz = 0`;
- `price_per_volume` negali būti apskaičiuotas, jei trūksta `price` arba `volume_xyz = 0`.

Todėl didesnis `NA` skaičius išvestiniuose požymiuose yra logiška bazinių duomenų trūkumų pasekmė.

---

## 10. Galutinė šio etapo išvada

Palyginus A02 duomenis su originalia `ggplot2::diamonds` baze nustatyta, kad:

- 14 neigiamų `carat` reikšmių buvo A02 rinkinyje pakeistos ir galėjo būti vienareikšmiškai atkurtos;
- 13 neigiamų `y` reikšmių taip pat galėjo būti atkurtos pagal originalią bazę;
- iš viso atkurta **27 sugadintos bazinių požymių reikšmės**;
- 3 `z = 0` reikšmės tokios pačios ir originaliame `diamonds` rinkinyje, todėl jos nebuvo keičiamos;
- po bazinių reikšmių atkūrimo buvo perskaičiuoti visi nuo jų priklausantys išvestiniai požymiai;
- dėl `z = 0` atsiradusios `Inf` reikšmės pakeistos į `NA`;
- po perskaičiavimo išvestinių požymių `NA` kiekis atspindi realius bazinių požymių trūkumus.

Svarbu pažymėti, kad originali duomenų bazė buvo naudojama tik aiškiai fiziškai nelogiškoms reikšmėms validuoti ir atkurti. Statistinės išskirtys pagal IQR taisyklę nėra automatiškai laikomos klaidomis ir turi būti analizuojamos atskirai.


[README.md](https://github.com/user-attachments/files/32465561/README.md)
