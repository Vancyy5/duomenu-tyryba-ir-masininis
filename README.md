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

Matavimo vienetų nuoseklumo patikra
Patikrinta, ar x, y, z yra tos pačios eilės dydžio (visi mm intervale, be dešimčių kartų skirtumo tarp stulpelių), ar depth ir table yra tame pačiame procentiniame intervale, ir ar price visur nurodytas ta pačia valiuta (€). Pastebėtos anomalijos buvo depth iki 239,06, y iki −11,85, z = 0.

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

## 3. Pirminė aprašomoji statistika

Prieš duomenų koregavimą apskaičiuojamos pagrindinės skaitinių požymių aprašomosios statistikos. Ši analizė atliekama po duomenų tipų sutvarkymo, bet dar prieš fiziškai nelogiškų reikšmių taisymą ir palyginimą su originalia `ggplot2::diamonds` baze.

Naudojamas kodas:

```r
numeric_cols_pries <- names(deimantai)[sapply(deimantai, is.numeric)]

aprasomoji_funkcija <- function(x) {

  x_valid <- x[!is.na(x)]

  c(
    n = length(x_valid),
    NA_kiekis = sum(is.na(x)),
    vidurkis = mean(x_valid),
    mediana = median(x_valid),
    standartinis_nuokrypis = sd(x_valid),
    minimumas = min(x_valid),
    Q1 = quantile(x_valid, 0.25),
    Q3 = quantile(x_valid, 0.75),
    maksimumas = max(x_valid)
  )
}

aprasomoji_pries <- t(
  sapply(
    deimantai[numeric_cols_pries],
    aprasomoji_funkcija
  )
)

aprasomoji_pries <- as.data.frame(aprasomoji_pries)

aprasomoji_pries$pozymis <- rownames(aprasomoji_pries)

aprasomoji_pries <- aprasomoji_pries[
  ,
  c(
    "pozymis",
    "n",
    "NA_kiekis",
    "vidurkis",
    "mediana",
    "standartinis_nuokrypis",
    "minimumas",
    "Q1",
    "Q3",
    "maksimumas"
  )
]

aprasomoji_pries[, -1] <- round(aprasomoji_pries[, -1], 3)

aprasomoji_pries
```

Papildomai galima naudoti:

```r
summary(deimantai)
```

Pirminė statistika parodė, kad kai kuriuose požymiuose yra labai neįprastų reikšmių.

Pavyzdžiui:

- `carat` turi neigiamų reikšmių;
- `y` turi neigiamų reikšmių;
- `z` turi nulinių reikšmių;
- `depth` mediana yra apie **61.7**, trečiasis kvartilis apie **62.2**, o maksimali reikšmė siekia **239.06**.

Tai rodo, kad duomenyse gali būti tiek fiziškai nelogiškų reikšmių, tiek statistinių išskirčių, todėl reikalinga tolesnė kokybės analizė.

---

## 4. Trūkstamų reikšmių analizė

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

Trūkstamų reikšmių pasiskirstymas pagal klasę:

| Požymis | Ideal | Premium |
|---|---:|---:|
| `carat` | 1.50 % | 1.50 % |
| `depth` | 0.90 % | 1.10 % |
| `price` | 1.50 % | 1.50 % |
| `volume_xyz` | 1.60 % | 1.40 % |
| `carat_per_volume` | 0.05 % | 0.10 % |
| `price_per_volume` | 0.05 % | 0.10 % |

### Išvada

Trūkstamų reikšmių kiekis nėra labai didelis, tačiau jos yra keliuose svarbiuose požymiuose. Trūkstamų reikšmių pasiskirstymas tarp `Ideal` ir `Premium` klasių yra labai panašus.

---

## 5. Dublikatų patikra

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

## 6. Klasių balanso tikrinimas

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

## 7. Nelogiškų reikšmių tikrinimas

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

## 8. Probleminių objektų nustatymas

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

Šios reikšmės neturėtų būti automatiškai pašalintos neįvertinus jų kilmės.

---

## 9. Konkrečių nelogiškų reikšmių peržiūra

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

## 10. Duomenų validavimas pagal originalią `ggplot2::diamonds` bazę

Šio etapo tikslas – patikrinti fiziškai nelogiškas A02 reikšmes, palyginti jas su originalia `ggplot2::diamonds` baze ir, kur galima, atkurti sugadintas bazinių požymių reikšmes.

Svarbu: originali bazė naudojama tik aiškiai fiziškai nelogiškoms reikšmėms validuoti, o ne statistinėms išskirtims automatiškai šalinti.

### 10.1. Originalios bazės paruošimas

```r
library(ggplot2)
library(dplyr)

originalas <- ggplot2::diamonds %>%
  mutate(
    class = as.character(cut)
  ) %>%
  filter(class %in% c("Ideal", "Premium"))

deimantai_su_id <- deimantai %>%
  mutate(a02_id = row_number())
```

Svarbu pažymėti, kad A02 eilutės numeris **neturi sutapti** su originalios `ggplot2::diamonds` bazės eilutės numeriu. `a02_id` naudojamas tik konkrečiai A02 eilutei identifikuoti. Atitikmenys originalioje bazėje ieškomi pagal kitų, nesugadintų požymių reikšmes.

---

### 10.2. Neigiamų `carat` reikšmių tikrinimas

Kadangi `carat` yra tikrinamas požymis, jis nenaudojamas ieškant atitikmens originalioje bazėje.

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

Visoms 14 probleminių `carat` eilučių buvo rastas aiškus originalus atitikmuo.

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

Visos 14 neigiamos `carat` reikšmės gali būti pagrįstai atkurtos pagal originalią bazę.

---

### 10.3. Neigiamų `y` reikšmių tikrinimas

Kadangi `y` yra tikrinamas požymis, jis nenaudojamas atitikmens paieškoje.

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

Vienai A02 eilutei (`a02_id = 3617`) originalioje bazėje rasti du atitikmenys, tačiau abiejuose `y_original = 4.45`, todėl atkuriama reikšmė vis tiek yra vienareikšmė.

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

Visos 13 neigiamos `y` reikšmės gali būti pagrįstai atkurtos pagal originalią bazę.

---

### 10.4. `z = 0` reikšmių tikrinimas

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

Todėl buvo tikrinti jų kiti požymiai ir atkirtos tikrosios z reikšmės.

---

## 11. Patikimai nustatytų reikšmių atkūrimas

Prieš taisant išsaugoma duomenų kopija:

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

```r
y_match_unique <- y_match %>%
  distinct(a02_id, .keep_all = TRUE)

for (i in 1:nrow(y_match_unique)) {
  deimantai$y[y_match_unique$a02_id[i]] <-
    y_match_unique$y_original[i]
}
```

Patikrinimas:

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

Iš viso atkurta **27 sugadintos bazinių požymių reikšmės**.

---

## 12. Išvestinių požymių perskaičiavimas

Kadangi dalis A02 požymių apskaičiuojama iš bazinių matavimų, po `carat` ir `y` atkūrimo išvestiniai požymiai perskaičiuojami iš naujo.

```r
deimantai$volume_xyz <- deimantai$x * deimantai$y * deimantai$z

deimantai$area_xy <- deimantai$x * deimantai$y
deimantai$area_xz <- deimantai$x * deimantai$z
deimantai$area_yz <- deimantai$y * deimantai$z

deimantai$price_per_carat <- deimantai$price / deimantai$carat

deimantai$length_width_ratio <- deimantai$x / deimantai$y

deimantai$depth_ratio <- deimantai$z / ((deimantai$x + deimantai$y) / 2)

deimantai$table_depth_ratio <- deimantai$table / deimantai$depth

deimantai$carat_per_volume <- deimantai$carat / deimantai$volume_xyz

deimantai$price_per_volume <- deimantai$price / deimantai$volume_xyz

deimantai$mean_dimension <- (deimantai$x + deimantai$y + deimantai$z) / 3
```

### `dimension_cv`

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

## 13. Trūkstamos reikšmės po perskaičiavimo

Po išvestinių požymių perskaičiavimo:

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

### Kodėl išvestiniuose požymiuose `NA` padaugėjo?

`price_per_carat` priklauso nuo `price` ir `carat`, todėl jei trūksta bent vienos bazinės reikšmės, išvestinis rodiklis taip pat negali būti apskaičiuotas.

Analogiškai:

- `table_depth_ratio` negali būti apskaičiuotas, jei trūksta `depth`;
- `carat_per_volume` negali būti apskaičiuotas, jei trūksta `carat` arba `volume_xyz = 0`;
- `price_per_volume` negali būti apskaičiuotas, jei trūksta `price` arba `volume_xyz = 0`.

---

## 14. Tarpinė aprašomoji statistika po `carat` ir `y` sutvarkymo

Po `carat` ir `y` atkūrimo bei išvestinių požymių perskaičiavimo aprašomoji statistika buvo apskaičiuota dar kartą. Tai yra tarpinis etapas prieš papildomą `depth` ir `price` validavimą.

```r
summary(deimantai)
colSums(is.na(deimantai))
```

Po sutvarkymo:

- `carat` minimumas tapo **0.23**, todėl neigiamų masės reikšmių nebeliko;
- `y` minimumas tapo **3.90**, todėl neigiamų geometrinių matmenų nebeliko;
- `z` minimumas liko **0**, nes trys tokios reikšmės egzistuoja ir originalioje `ggplot2::diamonds` bazėje;
- `price` vidurkis yra **4661.71**, o mediana **2442.50**, todėl kainos pasiskirstymas yra aiškiai asimetriškas į dešinę;
- `price_per_carat` vidurkis (**5208.44**) yra gerokai didesnis už medianą (**3584.07**), todėl šiame požymyje taip pat matoma ryški dešinioji uodega;
- `depth` mediana yra **61.7**, trečiasis kvartilis **62.2**, tačiau maksimumas siekia **239.06**, todėl ši reikšmė laikoma labai neįprasta ir turi būti tiriama atskirai;
- `Inf` reikšmių po perskaičiavimo nebeliko.

Tai rodo, kad aiškiai sugadintos bazinių požymių reikšmės buvo sutvarkytos, tačiau dalyje požymių vis dar išlieka statistiškai neįprastų reikšmių, kurias reikia vertinti atskirai.

---

## 15. Tarpinė aprašomoji statistika pagal klasę

Po bendros aprašomosios statistikos `Ideal` ir `Premium` klasės buvo analizuotos atskirai. Tai leidžia įvertinti, ar požymių pasiskirstymai ir kraštinės reikšmės priklauso nuo klasės.

Naudota funkcija:

```r
aprasomoji_klasei <- function(data) {

  numeric_cols <- names(data)[sapply(data, is.numeric)]

  rezultatas <- t(
    sapply(
      data[numeric_cols],
      aprasomoji_funkcija
    )
  )

  rezultatas <- as.data.frame(rezultatas)
  rezultatas$pozymis <- rownames(rezultatas)

  rezultatas <- rezultatas[
    ,
    c(
      "pozymis",
      "n",
      "NA_kiekis",
      "vidurkis",
      "mediana",
      "standartinis_nuokrypis",
      "minimumas",
      "Q1",
      "Q3",
      "maksimumas"
    )
  ]

  rezultatas[, -1] <- round(rezultatas[, -1], 3)

  rezultatas
}
```

### 15.1. Ideal klasė

```r
deimantai_ideal <- deimantai %>%
  filter(class == "Ideal")

aprasomoji_ideal <- aprasomoji_klasei(
  deimantai_ideal
)

aprasomoji_ideal
```

Svarbiausi rezultatai:

| Požymis | Vidurkis | Mediana | Q1 | Q3 | Maksimumas |
|---|---:|---:|---:|---:|---:|
| `carat` | 0.708 | 0.540 | 0.350 | 1.010 | 3.220 |
| `depth` | 62.369 | 61.800 | 61.300 | 62.200 | 239.060 |
| `table` | 55.931 | 56.000 | 55.000 | 57.000 | 62.000 |
| `price` | 4130.683 | 1851.000 | 903.250 | 5026.750 | 40816.500 |
| `volume_xyz` | 116.196 | 89.609 | 57.513 | 166.004 | 529.223 |
| `price_per_carat` | 5320.508 | 3374.259 | 2487.879 | 4891.340 | 147762.552 |

`Ideal` klasėje `price` ir `price_per_carat` vidurkiai yra gerokai didesni už medianas, todėl šių požymių pasiskirstymai yra asimetriški į dešinę. `depth` maksimumas **239.06** labai nutolęs nuo medianos **61.8**, todėl ši reikšmė turi būti tiriama atskirai.

### 15.2. Premium klasė

```r
deimantai_premium <- deimantai %>%
  filter(class == "Premium")

aprasomoji_premium <- aprasomoji_klasei(
  deimantai_premium
)

aprasomoji_premium
```

Svarbiausi rezultatai:

| Požymis | Vidurkis | Mediana | Q1 | Q3 | Maksimumas |
|---|---:|---:|---:|---:|---:|
| `carat` | 0.907 | 0.900 | 0.410 | 1.200 | 4.010 |
| `depth` | 61.527 | 61.400 | 60.500 | 62.200 | 220.670 |
| `table` | 58.747 | 59.000 | 58.000 | 60.000 | 62.000 |
| `price` | 5192.737 | 3393.000 | 1057.750 | 6688.250 | 40816.500 |
| `volume_xyz` | 147.107 | 140.983 | 67.480 | 194.027 | 631.894 |
| `price_per_carat` | 5096.366 | 3799.545 | 2631.707 | 5543.810 | 144562.439 |

`Premium` klasėje taip pat matoma ryški `price` ir `price_per_carat` dešinioji uodega. `depth` maksimumas **220.67** taip pat labai nutolęs nuo įprastų šios klasės reikšmių.

---

## 16. Tarpinis Ideal ir Premium klasių palyginimas

Pagrindinių požymių vidurkiai ir medianos buvo palyginti tiesiogiai:

```r
klasiu_palyginimas <- deimantai %>%
  group_by(class) %>%
  summarise(
    n = n(),

    carat_vidurkis = mean(carat, na.rm = TRUE),
    carat_mediana = median(carat, na.rm = TRUE),

    depth_vidurkis = mean(depth, na.rm = TRUE),
    depth_mediana = median(depth, na.rm = TRUE),

    table_vidurkis = mean(table, na.rm = TRUE),
    table_mediana = median(table, na.rm = TRUE),

    price_vidurkis = mean(price, na.rm = TRUE),
    price_mediana = median(price, na.rm = TRUE),

    volume_vidurkis = mean(volume_xyz, na.rm = TRUE),
    volume_mediana = median(volume_xyz, na.rm = TRUE),

    price_per_carat_vidurkis =
      mean(price_per_carat, na.rm = TRUE),

    price_per_carat_mediana =
      median(price_per_carat, na.rm = TRUE),

    .groups = "drop"
  )

klasiu_palyginimas
```

Pagrindiniai skirtumai:

| Požymis | Ideal | Premium |
|---|---:|---:|
| `carat` vidurkis | 0.708 | 0.907 |
| `carat` mediana | 0.540 | 0.900 |
| `depth` vidurkis | 62.369 | 61.527 |
| `depth` mediana | 61.800 | 61.400 |
| `table` vidurkis | 55.931 | 58.747 |
| `table` mediana | 56.000 | 59.000 |
| `price` vidurkis | 4130.683 | 5192.737 |
| `price` mediana | 1851.000 | 3393.000 |
| `volume_xyz` vidurkis | 116.196 | 147.107 |
| `volume_xyz` mediana | 89.609 | 140.983 |
| `price_per_carat` vidurkis | 5320.508 | 5096.366 |
| `price_per_carat` mediana | 3374.259 | 3799.545 |

### Išvada

`Premium` klasės deimantai šiame rinkinyje paprastai yra didesni:

- didesnis `carat` vidurkis ir mediana;
- didesnis `volume_xyz` vidurkis ir mediana;
- didesnės `x`, `y` ir `z` reikšmės;
- didesnis `table`.

`Premium` klasėje taip pat didesnė tiek vidutinė, tiek medianinė kaina.

`depth` medianos tarp klasių yra gana panašios, tačiau abiejose klasėse yra labai didelių ekstremalių reikšmių.

`price_per_carat` atveju `Ideal` klasės vidurkis yra šiek tiek didesnis, tačiau `Premium` mediana yra didesnė. Tai rodo, kad vien vidurkiu šio požymio skirtumų vertinti nepakanka, nes rezultatus stipriai veikia kraštinės reikšmės.

---

## 17. Tarpinis klasių pasiskirstymų vizualus palyginimas

Pagrindinių požymių skirtumai tarp klasių papildomai vertinami boxplot diagramomis:

```r
boxplot(
  carat ~ class,
  data = deimantai,
  main = "Carat pagal klasę",
  xlab = "Klasė",
  ylab = "Carat"
)

boxplot(
  price ~ class,
  data = deimantai,
  main = "Price pagal klasę",
  xlab = "Klasė",
  ylab = "Price"
)

boxplot(
  depth ~ class,
  data = deimantai,
  main = "Depth pagal klasę",
  xlab = "Klasė",
  ylab = "Depth"
)

boxplot(
  table ~ class,
  data = deimantai,
  main = "Table pagal klasę",
  xlab = "Klasė",
  ylab = "Table"
)

boxplot(
  volume_xyz ~ class,
  data = deimantai,
  main = "Volume pagal klasę",
  xlab = "Klasė",
  ylab = "Volume"
)
```

Taip pat sudaromos atskiros pagrindinių požymių histogramos kiekvienai klasei:

```r
pagrindiniai_pozymiai <- c(
  "carat",
  "depth",
  "table",
  "price",
  "volume_xyz",
  "price_per_carat"
)

for (col in pagrindiniai_pozymiai) {

  hist(
    deimantai_ideal[[col]],
    main = paste("Ideal klasė -", col),
    xlab = col,
    col = "lightblue",
    border = "white"
  )

  hist(
    deimantai_premium[[col]],
    main = paste("Premium klasė -", col),
    xlab = col,
    col = "lightblue",
    border = "white"
  )
}
```

Ši analizė leidžia įvertinti ne tik vidurkių ar medianų skirtumus, bet ir tai, kiek klasių pasiskirstymai persidengia bei kuriose klasėse dažniau pasitaiko kraštinių reikšmių.

---

## 18. Tarpinė požymių pasiskirstymo ir išskirčių analizė

Po duomenų sutvarkymo histogramų, boxplot diagramų ir IQR išskirčių analizė buvo pakartota, nes dalis reikšmių buvo pakoreguota.

### Histogramų sudarymas

```r
numeric_cols <- names(deimantai)[sapply(deimantai, is.numeric)]

for (col in numeric_cols) {
  hist(
    deimantai[[col]],
    main = col,
    xlab = col,
    col = "lightblue",
    border = "white"
  )
}
```

Histogramos naudojamos požymių pasiskirstymo formai, asimetrijai ir nuo pagrindinės reikšmių dalies nutolusioms reikšmėms įvertinti.

### Boxplot diagramų sudarymas

```r
for (col in numeric_cols) {
  boxplot(
    deimantai[[col]],
    main = col,
    ylab = col,
    col = "lightgreen"
  )
}
```

Boxplot diagramos leidžia vizualiai įvertinti medianą, kvartilius ir galimas statistines išskirtis.

### Išskirčių nustatymas pagal 1.5 × IQR taisyklę

```r
count_outliers <- function(x) {
  qnt <- quantile(x, probs = c(0.25, 0.75), na.rm = TRUE)
  H <- 1.5 * IQR(x, na.rm = TRUE)

  apacia <- qnt[1] - H
  virsus <- qnt[2] + H

  sum(x < apacia | x > virsus, na.rm = TRUE)
}

outlier_counts <- sapply(
  deimantai[numeric_cols],
  count_outliers
)

valid_counts <- sapply(
  deimantai[numeric_cols],
  function(x) sum(!is.na(x))
)

outlier_percent <- round(
  outlier_counts / valid_counts * 100,
  2
)

rezultatai_isskirtys <- data.frame(
  pozymis = names(outlier_counts),
  iskirciu_kiekis = outlier_counts,
  procentas = outlier_percent
)

rezultatai_isskirtys <- rezultatai_isskirtys[
  order(-rezultatai_isskirtys$iskirciu_kiekis),
]

rezultatai_isskirtys
```

Gauti rezultatai:

| Požymis | Išskirčių skaičius | Procentas |
|---|---:|---:|
| `price` | 295 | 7.49 % |
| `price_per_carat` | 163 | 4.20 % |
| `price_per_volume` | 163 | 4.14 % |
| `dimension_cv` | 116 | 2.90 % |
| `depth_ratio` | 114 | 2.85 % |
| `depth` | 98 | 2.47 % |
| `volume_xyz` | 61 | 1.52 % |
| `carat` | 60 | 1.52 % |
| `carat_per_volume` | 57 | 1.45 % |
| `table_depth_ratio` | 46 | 1.16 % |
| `area_xy` | 10 | 0.25 % |
| `area_xz` | 8 | 0.20 % |
| `area_yz` | 7 | 0.18 % |
| `z` | 6 | 0.15 % |
| `length_width_ratio` | 4 | 0.10 % |
| `x` | 2 | 0.05 % |
| `y` | 2 | 0.05 % |
| `mean_dimension` | 2 | 0.05 % |
| `table` | 1 | 0.03 % |

### Išvada

Daugiausia statistinių išskirčių nustatyta `price` požymyje – **295 reikšmės (7.49 %)**.

Taip pat daugiau išskirčių nustatyta `price_per_carat` (**4.20 %**), `price_per_volume` (**4.14 %**), `dimension_cv` (**2.90 %**), `depth_ratio` (**2.85 %**) ir `depth` (**2.47 %**) požymiuose.

Po duomenų sutvarkymo sumažėjo kai kurių požymių išskirčių skaičius, ypač `carat`, `y` ir `volume_xyz`. Tai rodo, kad dalis anksčiau nustatytų išskirčių buvo susijusios su sugadintomis bazinėmis reikšmėmis.

Svarbu pažymėti, kad IQR metodu nustatytos statistinės išskirtys nėra automatiškai laikomos klaidomis. Jos gali atspindėti realius, retesnius deimantus, todėl prieš jas šalinant ar koreguojant reikia įvertinti jų fizinę prasmę, pasiskirstymą ir ryšį su kitais požymiais.

---

---

## 19. Papildomas bazinių požymių validavimas

Po pirminio `carat` ir `y` sutvarkymo buvo pastebėta, kad `depth` ir `price` požymiuose vis dar yra reikšmių, kurios labai stipriai skiriasi nuo originalios `Ideal` ir `Premium` duomenų aibės ribų. Todėl atliktas papildomas šių dviejų požymių validavimas.

Originali bazė šiame etape naudojama tik aiškiai įtartinoms bazinių požymių reikšmėms tikrinti. Statistinės išskirtys vien dėl to, kad yra nutolusios nuo pagrindinės duomenų dalies, automatiškai nekoreguojamos ir nešalinamos.

### 19.1. `depth` reikšmių validavimas

Originalios `Ideal` ir `Premium` klasių `depth` ribos:

```text
43.0 – 66.7
```

A02 duomenyse rastos **13 `depth` reikšmių**, kurios buvo už šio intervalo ribų. Visoms 13 eilučių pagal kitus požymius originalioje bazėje rastas vienareikšmis atitikmuo.

| A02 eilutė | A02 `depth` | Originalus `depth` |
|---:|---:|---:|
| 341 | 194.24 | 62.4 |
| 1215 | 220.67 | 61.8 |
| 1368 | 200.43 | 60.5 |
| 1537 | 206.83 | 62.8 |
| 1879 | 236.04 | 61.9 |
| 1897 | 140.34 | 62.5 |
| 2419 | 239.06 | 62.1 |
| 2568 | 226.26 | 59.9 |
| 3011 | 215.28 | 61.9 |
| 3616 | 232.92 | 61.8 |
| 3748 | 222.99 | 60.1 |
| 3855 | 141.78 | 60.6 |
| 3975 | 229.04 | 62.6 |

Po atkūrimo:

```text
depth minimumas = 43.0
depth maksimumas = 65.1
reikšmių už originalios bazės ribų = 0
```

Kadangi `table_depth_ratio` priklauso nuo `depth`, šis išvestinis požymis buvo perskaičiuotas.

### 19.2. `price` reikšmių validavimas

Originalios `Ideal` ir `Premium` klasių kainų ribos:

```text
326 – 18823
```

A02 rinkinyje rastos **60 `price` reikšmių**, kurios buvo už originalios bazės ribų.

Ieškant atitikmens originalioje bazėje `price` požymis nebuvo naudojamas, nes būtent jis buvo tikrinamas.

Iš 60 įtartinų reikšmių:

- **49 `price` reikšmės** turėjo vienintelę galimą originalią reikšmę ir buvo atkurtos tiksliai;
- **11 `price` reikšmių** turėjo kelias galimas originalias reikšmes.

Pagal dėstytojos pastabą 11 nevienareikšmių atvejų buvo koreguoti naudojant **unikalių galimų originalių kainų aritmetinį vidurkį**.

| A02 eilutė | Galimos originalios `price` | Naudota reikšmė |
|---:|---|---:|
| 331 | 828, 900 | 864 |
| 1112 | 591, 865 | 728 |
| 1138 | 1574, 1974 | 1774 |
| 1485 | 408, 891, 901, 924 | 781 |
| 1607 | 605, 737 | 671 |
| 2409 | 943, 1056 | 999.5 |
| 2502 | 1073, 1155 | 1114 |
| 2715 | 872, 997 | 934.5 |
| 3306 | 555, 596, 773, 1133 | 764.25 |
| 3522 | 1145, 1637 | 1391 |
| 3782 | 11550, 11654 | 11602 |

Po visų `price` korekcijų:

```text
price minimumas = 348
price maksimumas = 18784
reikšmių už originalios bazės ribų = 0
```

Taigi visos 60 aiškiai įtartinų `price` reikšmių buvo apdorotos: 49 atkurtos tiksliai, o 11 įvertintos pagal kelių galimų originalių reikšmių vidurkį.

Po kainų koregavimo perskaičiuoti `price_per_carat` ir `price_per_volume`.

---

## 20. Duomenų kokybės būklė po bazinių reikšmių validavimo

Po atlikto validavimo:

- atkurtos **14 `carat`** reikšmių;
- atkurtos **13 `y`** reikšmių;
- atkurtos **13 `depth`** reikšmių;
- **49 `price`** reikšmės atkurtos vienareikšmiškai;
- **11 `price`** reikšmių pakeistos galimų originalių kainų vidurkiu;
- visi nuo pakoreguotų bazinių požymių priklausantys išvestiniai požymiai perskaičiuoti;


Svarbu atskirti, kad **89 bazinės reikšmės buvo atkurtos tiksliai**, o dar **11 `price` reikšmių buvo įvertintos pagal kelių galimų atitikmenų vidurkį**.

---

## 21. Trūkstamų reikšmių analizė

Po bazinių požymių validavimo trūkstamų reikšmių situacija buvo:

| Požymis | `NA` kiekis | Procentas |
|---|---:|---:|
| `carat` | 60 | 1.50 % |
| `depth` | 40 | 1.00 % |
| `price` | 60 | 1.50 % |
| `price_per_carat` | 120 | 3.00 % |
| `table_depth_ratio` | 40 | 1.00 % |
| `carat_per_volume` | 63 | 1.57 % |
| `price_per_volume` | 63 | 1.57 % |

Bazinių požymių trūkstamos reikšmės pagal klases buvo pasiskirsčiusios panašiai:

| Klasė | `carat` NA | `depth` NA | `price` NA |
|---|---:|---:|---:|
| Ideal | 30 (1.5 %) | 18 (0.9 %) | 30 (1.5 %) |
| Premium | 30 (1.5 %) | 22 (1.1 %) | 30 (1.5 %) |

Tai rodo, kad trūkstamos reikšmės nėra stipriai susitelkusios vienoje klasėje.

---

## 22. Palyginamasis eksperimentas: `carat` pildymas vidurkiu ir mediana

Palyginamajam eksperimentui pasirinktas vienas aiškus pirminio apdorojimo sprendimas – `carat` trūkstamų reikšmių pildymas.

Apskaičiuota:

```text
carat vidurkis = 0.807
carat mediana = 0.700
```

Palyginti du variantai:

1. trūkstamos `carat` reikšmės užpildomos vidurkiu;
2. trūkstamos `carat` reikšmės užpildomos mediana.

| Rodiklis | Prieš pildymą | Pildymas vidurkiu | Pildymas mediana |
|---|---:|---:|---:|
| Vidurkis | 0.807 | 0.807 | 0.806 |
| Mediana | 0.700 | 0.700 | 0.700 |
| SD | 0.499 | 0.495 | 0.495 |
| Q1 | 0.380 | 0.380 | 0.380 |
| Q3 | 1.090 | 1.080 | 1.080 |

Išskirčių skaičius:

| Variantas | Išskirčių skaičius |
|---|---:|
| Prieš pildymą | 60 |
| Pildymas vidurkiu | 66 |
| Pildymas mediana | 66 |

Abu metodai pagrindines statistikas pakeitė nedaug. Tolimesniam pildymui pasirinkta **mediana**, nes ji yra mažiau jautri asimetrijai ir kraštinėms reikšmėms.

---

## 23. Bazinių trūkstamų reikšmių užpildymas mediana

Galutinės bazinių požymių medianos:

```text
carat = 0.7
depth = 61.7
price = 2364.5
```

Šiomis reikšmėmis užpildytos trūkstamos `carat`, `depth` ir `price` reikšmės.

Po pildymo perskaičiuoti nuo jų priklausantys išvestiniai požymiai.

Galutinis `NA` skaičius:

- `carat` – 0;
- `depth` – 0;
- `price` – 0;
- `price_per_carat` – 0;
- `table_depth_ratio` – 0;
- `carat_per_volume` – 0;
- `price_per_volume` – 0.

---

## 24. Galutinė aprašomoji statistika

Po visų korekcijų ir medianos pildymo gauti šie svarbiausi rezultatai:

| Požymis | Vidurkis | Mediana | SD | Minimumas | Q1 | Q3 | Maksimumas |
|---|---:|---:|---:|---:|---:|---:|---:|
| `carat` | 0.806 | 0.700 | 0.495 | 0.230 | 0.380 | 1.080 | 4.010 |
| `depth` | 61.470 | 61.700 | 1.020 | 43.000 | 61.000 | 62.200 | 65.100 |
| `price` | 4103.792 | 2364.500 | 4241.079 | 348.000 | 971.750 | 5708.500 | 18784.000 |
| `price_per_carat` | 4148.863 | 3528.382 | 2220.793 | 617.143 | 2586.019 | 5139.918 | 24827.143 |
| `price_per_volume` | 25.228 | 21.538 | 12.995 | 6.938 | 15.599 | 31.284 | 131.045 |
| `table_depth_ratio` | 0.933 | 0.929 | 0.040 | 0.684 | 0.905 | 0.959 | 1.256 |

`price`, `price_per_carat`, `price_per_volume`, `carat` ir dalis geometrinių išvestinių požymių išlieka asimetriški, tačiau nebėra ankstesnių aiškiai sugadintų ekstremalių `price` ir `depth` reikšmių.

---

## 25. Išskirčių analizė po galutinio sutvarkymo

Po medianos pildymo IQR analizė pakartota su pilnai sutvarkytais duomenimis.

| Požymis | Išskirčių skaičius | Procentas |
|---|---:|---:|
| `price` | 265 | 6.62 % |
| `price_per_carat` | 136 | 3.40 % |
| `price_per_volume` | 132 | 3.30 % |
| `dimension_cv` | 116 | 2.90 % |
| `depth_ratio` | 114 | 2.85 % |
| `depth` | 113 | 2.83 % |
| `carat_per_volume` | 112 | 2.80 % |
| `carat` | 66 | 1.65 % |
| `volume_xyz` | 61 | 1.52 % |
| `table_depth_ratio` | 33 | 0.83 % |
| `area_xy` | 10 | 0.25 % |
| `area_xz` | 8 | 0.20 % |
| `area_yz` | 7 | 0.18 % |
| `z` | 6 | 0.15 % |
| `length_width_ratio` | 4 | 0.10 % |
| `x` | 2 | 0.05 % |
| `y` | 2 | 0.05 % |
| `mean_dimension` | 2 | 0.05 % |
| `table` | 1 | 0.03 % |

IQR metodu nustatytos reikšmės **nėra automatiškai laikomos klaidomis**. Po sugadintų bazinių reikšmių validavimo likusios statistinės išskirtys šiame laboratoriniame darbe tik identifikuojamos ir aprašomos. Pagal dėstytojos pastabą jų šalinimas bus nagrinėjamas kitame darbe.

---

## 26. Pasiskirstymų asimetrijos analizė

Kad mastelio keitimo metodo pasirinkimas būtų grindžiamas ne vien `price`, apskaičiuotas kiekvieno skaitinio požymio asimetrijos koeficientas (`skewness`).

Praktiniam palyginimui naudota riba:

- `|skewness| <= 0.5` – pasiskirstymas gana simetriškas;
- `|skewness| > 0.5` – pasiskirstymas pastebimai asimetriškas.

Rezultatas:

```text
Asimetriškų skaitinių požymių: 13 iš 19
```

Ryškiau asimetriški buvo `price`, `price_per_carat`, `price_per_volume`, `carat`, `volume_xyz`, `area_xy`, `area_xz`, `area_yz` ir keli santykiniai požymiai.

---

## 27. Mastelio keitimo metodų palyginimas

Mastelio keitimas atliekamas **tik po pilno duomenų validavimo, trūkstamų reikšmių pildymo ir išvestinių požymių perskaičiavimo**.

Palyginti trys metodai:

1. standartizavimas;
2. Min–Max normalizavimas;
3. Robust Scaling.

### 27.1. Reikšmių ribų palyginimas

| Metodas | `carat` min | `carat` max | `price` min | `price` max |
|---|---:|---:|---:|---:|
| Pradiniai sutvarkyti duomenys | 0.230 | 4.010 | 348.000 | 18784.000 |
| Standardizavimas | -1.162 | 6.469 | -0.886 | 3.461 |
| Min–Max | 0.000 | 1.000 | 0.000 | 1.000 |
| Robust Scaling | -0.671 | 4.729 | -0.426 | 3.466 |

### 27.2. `price` statistikos po mastelio keitimo

| Metodas | Vidurkis | Mediana | SD |
|---|---:|---:|---:|
| Pradiniai | 4103.792 | 2364.500 | 4241.079 |
| Standardizavimas | 0.000 | -0.410 | 1.000 |
| Min–Max | 0.204 | 0.109 | 0.230 |
| Robust Scaling | 0.367 | 0.000 | 0.895 |

### Išvada

Standardizavimas remiasi vidurkiu ir standartiniu nuokrypiu, todėl yra jautresnis išskirtims. Min–Max metodas tiesiogiai priklauso nuo minimumo ir maksimumo.

Kadangi **13 iš 19 skaitinių požymių yra asimetriški**, o po duomenų validavimo išlieka realių statistinių išskirčių, tolimesniam mastelio keitimui pasirinktas **Robust Scaling**, kuris remiasi mediana ir IQR.

---

## 28. Požymių ryšių ir koreliacijų analizė

Ryšiams įvertinti pateikiami tiek **Pearson**, tiek **Spearman** koreliacijos koeficientai.

Pearson geriau aprašo tiesinį ryšį, o Spearman – monotonišką ryšį ir yra mažiau jautrus išskirtims. Kadangi daug požymių yra asimetriški ir turi išskirčių, pagrindinei ryšių interpretacijai daugiau remiamasi **Spearman**, tačiau abu koeficientai pateikiami palyginimui.

### 28.1. Pagrindinių porų palyginimas

| Požymių pora | Pearson | Spearman |
|---|---:|---:|
| `carat` – `price` | 0.912 | 0.948 |
| `volume_xyz` – `price` | 0.916 | 0.951 |
| `carat` – `volume_xyz` | 0.989 | 0.988 |

`carat` ir `price` bei `volume_xyz` ir `price` turi labai stiprų teigiamą monotonišką ryšį. `carat` ir `volume_xyz` ryšys yra beveik tobulas ir pagal Pearson, ir pagal Spearman.

### 28.2. Stipriausiai koreliuojantys požymiai

Spearman koreliacijų matricoje nustatytos **52 poros**, kurių absoliuti koreliacija yra bent 0.90.

Stipriausių pavyzdžiai:

| Požymis 1 | Požymis 2 | Spearman |
|---|---|---:|
| `dimension_cv` | `depth_ratio` | -1.000 |
| `area_xy` | `y` | 1.000 |
| `area_xy` | `x` | 1.000 |
| `area_yz` | `area_xz` | 0.999 |
| `area_xz` | `volume_xyz` | 0.999 |
| `area_yz` | `volume_xyz` | 0.999 |
| `mean_dimension` | `area_xy` | 0.999 |
| `mean_dimension` | `volume_xyz` | 0.999 |

### 28.3. Stipriai koreliuojančių požymių grupės

Šiame darbe požymiai **dar nešalinami**. Jie tik identifikuojami ir grupuojami:

**Dydžio ir geometrijos grupė:**

`carat`, `x`, `y`, `z`, `volume_xyz`, `area_xy`, `area_xz`, `area_yz`, `mean_dimension`.

**Kainos santykiniai požymiai:**

`price_per_carat`, `price_per_volume`.

**Proporcijų ir formos požymiai:**

`depth_ratio`, `dimension_cv`, `length_width_ratio`, `table_depth_ratio`.

Požymių mažinimas ir atranka bus atliekami kitame laboratoriniame darbe.

---

## 29. Galutinis `Ideal` ir `Premium` klasių palyginimas

Abiejose klasėse yra po 2000 objektų.

| Požymis | Ideal mediana | Premium mediana |
|---|---:|---:|
| `carat` | 0.550 | 0.820 |
| `depth` | 61.800 | 61.400 |
| `table` | 56.000 | 59.000 |
| `price` | 1841.500 | 3025.500 |
| `volume_xyz` | 89.609 | 140.983 |
| `price_per_carat` | 3336.055 | 3773.255 |

Papildomai vidutinės reikšmės:

- `price`: Ideal ≈ **3540**, Premium ≈ **4667**;
- `price_per_carat`: Ideal ≈ **4019**, Premium ≈ **4278**.

### Išvada

Šiame rinkinyje `Premium` klasės deimantai:

- paprastai yra didesni pagal `carat` ir `volume_xyz`;
- turi didesnę medianinę ir vidutinę kainą;
- turi didesnį `table`;
- pagal `depth` nuo `Ideal` klasės skiriasi nedaug;
- turi didesnę medianinę `price_per_carat` reikšmę.

---

## 30. Duomenų rinkinio tinkamumo tolesnei analizei vertinimas

### 30.1. Galutinė rinkinio būklė

| Rodiklis | Reikšmė |
|---|---:|
| Objektų skaičius | 4000 |
| Požymių skaičius | 20 |
| `Ideal` objektai | 2000 |
| `Premium` objektai | 2000 |
| Dublikatų skaičius | 0 |
| Likusių `NA` skaičius | 0 |

Galutinė bazinių požymių loginė patikra:

| Tikrinimas | Kiekis |
|---|---:|
| `carat <= 0` | 0 |
| `price <= 0` | 0 |
| `x <= 0` | 0 |
| `y <= 0` | 0 |
| `z <= 0` | 0 |
| `depth <= 0` | 0 |
| `table <= 0` | 0 |

### 30.2. Stiprybės

- 4000 objektų;
- klasės visiškai subalansuotos;
- nėra pilnų dublikatų;
- aiškiai sugadintos bazinės reikšmės validuotos pagal originalią bazę;
- 89 reikšmės atkurtos tiksliai;
- 11 nevienareikšmių kainų įvertintos pagal galimų originalių reikšmių vidurkį;
- trūkstamų bazinių reikšmių dalis nedidelė;
- po korekcijų perskaičiuoti išvestiniai požymiai;
- nustatyti aiškūs ryšiai tarp dydžio, tūrio ir kainos;
- klasės skiriasi pagal kelis svarbius požymius.

### 30.3. Apribojimai

1. **11 įvertintų `price` reikšmių.** Jos nėra tiksliai atkurtos – naudotas kelių galimų originalių kainų vidurkis. Todėl jos turėtų būti laikomos įvertintomis, o ne tiksliai žinomomis reikšmėmis.

2. **Daug stipriai koreliuojančių požymių.** Dalis geometrinių požymių dubliuoja panašią informaciją. Šiame darbe jie tik identifikuojami ir grupuojami.

3. **Statistinės išskirtys.** Po klaidingų reikšmių sutvarkymo išskirtys vis dar egzistuoja, tačiau šiame darbe jos nešalinamos.

### 30.4. Tinkamumas mašininiam mokymuisi

Duomenų rinkinys laikomas tinkamu tolimesnei statistinei analizei ir mašininio mokymosi eksperimentams.

Jei metodas jautrus požymių masteliui, galima naudoti pasirinktą **Robust Scaling**.

Jei modelis jautrus stipriai koreliuojantiems požymiams, požymių atranka ar mažinimas turėtų būti atliekami kitame laboratoriniame darbe.

---

## 31. Galutinės darbo išvados

1. A02 duomenų rinkinį sudaro **4000 objektų ir 20 požymių**, iš kurių 19 skaitinių ir vienas kategorinis `class`.

2. `Ideal` ir `Premium` klasės yra visiškai subalansuotos – po 2000 objektų.

3. Pradinėje aibėje buvo netinkamų duomenų tipų, trūkstamų reikšmių ir aiškiai nelogiškų ar sugadintų bazinių reikšmių.

4. Pagal originalią `ggplot2::diamonds` bazę tiksliai atkurtos **89 reikšmės**: 14 `carat`, 13 `y`, 13 `depth` ir 49 `price`.

5. Dar **11 `price` reikšmių** turėjo kelis galimus originalius atitikmenis, todėl pagal dėstytojos nurodymą jos pakeistos galimų originalių kainų vidurkiu.

6. Po `price` korekcijų neliko kainų už originalios bazės ribų; galutinės neimputuotos `price` reikšmės buvo intervale **348–18784**.

7. Trys `z = 0` objektai palikti, nes tokios reikšmės egzistuoja ir originalioje bazėje, jos buvo perskaičiuotos

8. Trūkstamoms bazinėms reikšmėms pildyti palyginti vidurkio ir medianos metodai. Pasirinkta mediana.

9. Galutinės pildymui naudotos medianos: `carat = 0.7`, `depth = 61.7`, `price = 2364.5`.

10. Po viso sutvarkymo daugiausia IQR išskirčių liko `price` požymyje – **265 (6.62 %)**, tačiau jos šiame darbe automatiškai nešalinamos.

11. Asimetrijos analizė parodė, kad **13 iš 19 skaitinių požymių** yra pastebimai asimetriški. Dėl to ir dėl realių išskirčių mastelio keitimui pasirinktas **Robust Scaling**.

12. Koreliacijų analizė parodė stiprų deimanto dydžio ir kainos ryšį: `carat–price` Spearman = **0.948**, `volume_xyz–price` = **0.951**.

13. Daug geometrinių bazinių ir išvestinių požymių labai stipriai koreliuoja tarpusavyje, todėl jie suskirstyti į logines grupes. Šiame darbe požymiai dar nešalinami.

14. `Premium` klasės deimantai šiame rinkinyje paprastai yra didesni ir brangesni už `Ideal` klasės deimantus.

15. Galutiniame rinkinyje nėra pilnų dublikatų, klasės subalansuotos, o didžioji dalis kokybės problemų išspręsta. Duomenų aibė laikoma tinkama tolimesnei analizei.

---

## Galutinė duomenų būklė

| Charakteristika | Galutinė reikšmė |
|---|---:|
| Objektai | 4000 |
| Požymiai | 20 |
| Ideal | 2000 |
| Premium | 2000 |
| Dublikatai | 0 |
| Likę NA | 6 |
| Tiksliai atkurtos sugadintos bazinės reikšmės | 89 |
| Pagal galimų kainų vidurkį įvertintos `price` reikšmės | 11 |
| Asimetriški skaitiniai požymiai | 13 iš 19 |