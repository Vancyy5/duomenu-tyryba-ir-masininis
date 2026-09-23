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

Todėl jos nelaikomos A02 rinkinio sugadinimo rezultatu ir nebuvo keičiamos.

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

---

## 13. `Inf` reikšmių tvarkymas

Kadangi trijose eilutėse `z = 0`, gaunama:

```text
volume_xyz = 0
```

Todėl:

```text
carat_per_volume = carat / 0
price_per_volume = price / 0
```

gali tapti `Inf`.

Tokios reikšmės pakeičiamos į `NA`:

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

Taigi po sutvarkymo `Inf` reikšmių duomenyse nebeliko.

---

## 14. Trūkstamos reikšmės po perskaičiavimo

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

## 15. Aprašomoji statistika po sutvarkymo

Po bazinių požymių atkūrimo pagal originalią `ggplot2::diamonds` bazę ir išvestinių požymių perskaičiavimo aprašomoji statistika buvo apskaičiuota dar kartą.

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

## 16. Aprašomoji statistika pagal klasę

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

### 16.1. Ideal klasė

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

### 16.2. Premium klasė

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

## 17. Ideal ir Premium klasių palyginimas

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

## 18. Klasių pasiskirstymų vizualus palyginimas

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

## 19. Požymių pasiskirstymo ir išskirčių analizė

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
## 17. Papildomas bazinių požymių validavimas

Po pirminio duomenų sutvarkymo buvo pastebėta, kad kai kurių bazinių požymių reikšmės vis dar labai stipriai skiriasi nuo įprasto diapazono. Todėl papildomai buvo patikrinti `depth` ir `price` požymiai, lyginant A02 duomenis su originalia `ggplot2::diamonds` baze.

Šiame etape originali bazė naudojama tik aiškiai įtartinoms bazinių požymių reikšmėms validuoti. Statistinės išskirtys nėra automatiškai keičiamos vien todėl, kad jos yra nutolusios nuo pagrindinės duomenų dalies.

### 17.1. `depth` reikšmių validavimas

Pirmiausia nustatytos originalios `Ideal` ir `Premium` klasių `depth` ribos:

```r
depth_min_original <- min(originalas$depth, na.rm = TRUE)
depth_max_original <- max(originalas$depth, na.rm = TRUE)

depth_min_original
depth_max_original
```

Gautos ribos:

```text
43.0 – 66.7
```

A02 duomenyse buvo ieškoma `depth` reikšmių, kurios išeina už šio intervalo:

```r
itartinas_depth <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(
    !is.na(depth) &
      (
        depth < depth_min_original |
        depth > depth_max_original
      )
  )

nrow(itartinas_depth)
```

Rasta **13 įtartinų `depth` reikšmių**.

Jų A02 reikšmės buvo:

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

Visoms 13 eilutėms originalioje bazėje buvo rastas vienareikšmis atitikmuo, todėl reikšmės buvo atkurtos:

```r
for (i in seq_len(nrow(depth_match_unique))) {
  deimantai$depth[
    depth_match_unique$a02_id[i]
  ] <- depth_match_unique$depth_original[i]
}
```

Kadangi `table_depth_ratio` priklauso nuo `depth`, šis išvestinis požymis buvo perskaičiuotas:

```r
deimantai$table_depth_ratio <-
  deimantai$table / deimantai$depth
```

Po atkūrimo:

```text
depth minimumas = 43.0
depth maksimumas = 65.1
įtartinų reikšmių už originalios bazės ribų = 0
```

### Išvada

Visos 13 labai didelės `depth` reikšmės buvo A02 rinkinio sugadinimo rezultatas. Jas pavyko vienareikšmiškai atkurti pagal originalią `ggplot2::diamonds` bazę.

---

## 18. `price` reikšmių validavimas

Toliau analogiškai patikrintas `price` požymis.

Originalios `Ideal` ir `Premium` klasių kainų ribos:

```r
price_min_original <- min(originalas$price, na.rm = TRUE)
price_max_original <- max(originalas$price, na.rm = TRUE)
```

Gauta:

```text
326 – 18823
```

A02 rinkinyje rastos **60 `price` reikšmių**, kurios viršijo originalios bazės maksimumą.

```r
itartinas_price <- deimantai %>%
  mutate(a02_id = row_number()) %>%
  filter(
    !is.na(price) &
      (
        price < price_min_original |
        price > price_max_original
      )
  )

nrow(itartinas_price)
```

### 18.1. Vienareikšmiškai atkuriamos kainos

Ieškant atitikmenų originalioje bazėje `price` požymis nebuvo naudojamas, nes būtent jis buvo tikrinamas.

Iš 60 įtartinų kainų **49 reikšmėms rastas vienintelis galimas originalus atitikmuo**.

Pavyzdžiai:

| A02 eilutė | A02 `price` | Originalus `price` |
|---:|---:|---:|
| 88 | 34554.52 | 1669 |
| 165 | 36639.98 | 625 |
| 170 | 40816.50 | 1787 |
| 406 | 40816.50 | 2804 |
| 413 | 40816.50 | 2425 |
| 564 | 37804.70 | 3084 |
| 675 | 35226.59 | 816 |
| 721 | 40816.50 | 961 |
| 842 | 37124.47 | 598 |
| 999 | 40816.50 | 2181 |

Šios 49 kainos buvo atkurtos:

```r
for (i in seq_len(nrow(price_match_unique))) {

  deimantai$price[
    price_match_unique$a02_id[i]
  ] <- price_match_unique$price_original[i]
}
```

### 18.2. Nevienareikšmiai `price` atitikmenys

Likusioms **11 eilučių** pagal kitus bazinius požymius buvo rasti keli galimi originalūs objektai su skirtingomis kainomis.

| A02 eilutė | A02 `price` | Galimos originalios reikšmės |
|---:|---:|---|
| 331 | 40816.50 | 828, 900 |
| 1112 | 40816.50 | 591, 865 |
| 1138 | 40816.50 | 1574, 1974 |
| 1485 | 34958.59 | 408, 891, 901, 924 |
| 1607 | 34306.31 | 605, 737 |
| 2409 | 38270.46 | 943, 1056 |
| 2502 | 36770.56 | 1073, 1155 |
| 2715 | 36576.41 | 872, 997 |
| 3306 | 36189.88 | 555, 596, 773, 1133 |
| 3522 | 38555.01 | 1145, 1637 |
| 3782 | 34137.59 | 11550, 11654 |

Kadangi iš turimų požymių negalima pagrįstai nustatyti, kuri iš kelių originalių kainų priklauso konkrečiai A02 eilutei, šios 11 reikšmių **nebuvo automatiškai keičiamos**.

Taip išvengiama nepagrįsto reikšmių spėjimo.

### 18.3. Išvestinių kainos požymių perskaičiavimas

Po 49 vienareikšmių `price` reikšmių atkūrimo perskaičiuoti nuo kainos priklausantys požymiai:

```r
deimantai$price_per_carat <-
  deimantai$price / deimantai$carat

deimantai$price_per_volume <-
  deimantai$price / deimantai$volume_xyz

deimantai$price_per_volume[
  is.infinite(deimantai$price_per_volume)
] <- NA
```

Po perskaičiavimo `Inf` reikšmių nėra.

### Išvada

Iš 60 aiškiai įtartinų `price` reikšmių **49 buvo vienareikšmiškai atkurtos**, o **11 liko nevienareikšmės ir nebuvo automatiškai keičiamos**.

---

## 19. Aprašomoji statistika po papildomo `depth` ir `price` sutvarkymo

Po `depth` ir 49 vienareikšmių `price` reikšmių atkūrimo aprašomoji statistika buvo perskaičiuota.

Svarbiausi rezultatai:

| Požymis | Vidurkis | Mediana | Minimumas | Q1 | Q3 | Maksimumas |
|---|---:|---:|---:|---:|---:|---:|
| `carat` | 0.807 | 0.700 | 0.230 | 0.380 | 1.090 | 4.010 |
| `depth` | 61.468 | 61.700 | 43.000 | 60.900 | 62.200 | 65.100 |
| `table` | 57.339 | 57.000 | 43.000 | 56.000 | 59.000 | 62.000 |
| `price` | 4229.414 | 2385.500 | 348.000 | 968.000 | 5808.500 | 40816.500 |
| `price_per_carat` | 4384.222 | 3542.582 | 1140.625 | 2587.097 | 5101.911 | 131666.129 |
| `price_per_volume` | 26.844 | 21.600 | 6.938 | 15.648 | 31.305 | 792.743 |
| `table_depth_ratio` | 0.933 | 0.929 | 0.684 | 0.905 | 0.959 | 1.256 |

Po `depth` atkūrimo šio požymio standartinis nuokrypis sumažėjo iki **1.024**, o maksimumas – iki **65.1**, todėl anksčiau buvusi labai didelė sklaida buvo susijusi su sugadintomis reikšmėmis.

`price` vidurkis po 49 klaidingų kainų atkūrimo sumažėjo nuo ankstesnės reikšmės, tačiau vis dar yra didesnis už medianą, todėl pasiskirstymas išlieka asimetriškas į dešinę. Tam įtakos turi ir 11 nevienareikšmių kainų, kurios nebuvo keičiamos.

---

## 20. Išskirčių analizė po papildomo sutvarkymo

Po `depth` ir dalies `price` reikšmių atkūrimo IQR analizė buvo pakartota.

Gauti rezultatai:

| Požymis | Išskirčių skaičius | Procentas |
|---|---:|---:|
| `price` | 264 | 6.70 % |
| `price_per_carat` | 145 | 3.74 % |
| `price_per_volume` | 143 | 3.63 % |
| `dimension_cv` | 116 | 2.90 % |
| `depth_ratio` | 114 | 2.85 % |
| `depth` | 85 | 2.15 % |
| `volume_xyz` | 61 | 1.52 % |
| `carat` | 60 | 1.52 % |
| `carat_per_volume` | 57 | 1.45 % |
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

### Palyginimas su ankstesne analize

Po papildomo duomenų sutvarkymo:

- `price` IQR išskirčių sumažėjo nuo **295 iki 264**;
- `price_per_carat` – nuo **163 iki 145**;
- `price_per_volume` – nuo **163 iki 143**;
- `depth` – nuo **98 iki 85**;
- `table_depth_ratio` – nuo **46 iki 33**.

Tai rodo, kad dalis anksčiau nustatytų statistinių išskirčių buvo susijusios ne su natūralia duomenų variacija, o su sugadintomis bazinių požymių reikšmėmis.

Vis dėlto IQR metodu nustatytos likusios išskirtys nėra automatiškai laikomos klaidomis. Jas reikia vertinti pagal jų fizinę prasmę ir ryšį su kitais požymiais.

---

## 21. Dabartinė duomenų kokybės būklė

Po atlikto validavimo:

- atkurtos **14 `carat`** reikšmių;
- atkurtos **13 `y`** reikšmių;
- atkurtos **13 `depth`** reikšmių;
- atkurtos **49 vienareikšmės `price`** reikšmės;
- 3 `z = 0` reikšmės paliktos, nes jos tokios pačios ir originalioje bazėje;
- 11 įtartinų `price` reikšmių paliktos nepakeistos, nes jų originalių reikšmių nepavyko nustatyti vienareikšmiškai;
- po išvestinių požymių perskaičiavimo `Inf` reikšmių nebeliko.

Taigi iš viso patikimai atkurtos **89 sugadintos bazinių požymių reikšmės**:

```text
14 carat + 13 y + 13 depth + 49 price = 89
```

---

## 22. Trūkstamų reikšmių analizė ir apdorojimo metodo pasirinkimas

Po bazinių požymių validavimo ir sugadintų reikšmių atkūrimo buvo iš naujo įvertintos trūkstamos reikšmės.

Gauti rezultatai:

| Požymis | `NA` kiekis | Procentas |
|---|---:|---:|
| `carat` | 60 | 1.50 % |
| `depth` | 40 | 1.00 % |
| `price` | 60 | 1.50 % |
| `price_per_carat` | 120 | 3.00 % |
| `table_depth_ratio` | 40 | 1.00 % |
| `carat_per_volume` | 63 | 1.57 % |
| `price_per_volume` | 63 | 1.57 % |

Trūkstamos bazinių požymių reikšmės tarp klasių pasiskirstė panašiai:

| Klasė | `carat` NA | `depth` NA | `price` NA |
|---|---:|---:|---:|
| Ideal | 30 (1.5 %) | 18 (0.9 %) | 30 (1.5 %) |
| Premium | 30 (1.5 %) | 22 (1.1 %) | 30 (1.5 %) |

Taip pat patikrinta, ar bazinių požymių trūkstamos reikšmės persidengia:

- `carat` ir `depth` vienu metu trūko 2 eilutėse;
- `carat` ir `price` vienu metu netrūko nė vienoje eilutėje;
- `depth` ir `price` vienu metu netrūko nė vienoje eilutėje;
- visų trijų požymių vienu metu netrūko nė vienoje eilutėje.

Tai rodo, kad trūkstamos reikšmės nėra stipriai susitelkusios vienoje klasėje ar tose pačiose eilutėse.

---

## 23. Palyginamasis eksperimentas: `carat` pildymas vidurkiu ir mediana

Siekiant pagrįsti trūkstamų reikšmių pildymo metodą, atliktas palyginamasis eksperimentas su `carat` požymiu.

`carat` turi 60 trūkstamų reikšmių, t. y. 1.5 % visų objektų.

Apskaičiuotos reikšmės:

```text
carat vidurkis = 0.807
carat mediana = 0.700
```

Buvo sukurti du variantai:

1. trūkstamos `carat` reikšmės užpildytos vidurkiu;
2. trūkstamos `carat` reikšmės užpildytos mediana.

Gauti statistikos rezultatai:

| Rodiklis | Prieš pildymą | Pildymas vidurkiu | Pildymas mediana |
|---|---:|---:|---:|
| Vidurkis | 0.807 | 0.807 | 0.806 |
| Mediana | 0.700 | 0.700 | 0.700 |
| SD | 0.499 | 0.495 | 0.495 |
| Q1 | 0.380 | 0.380 | 0.380 |
| Q3 | 1.090 | 1.080 | 1.080 |

Išskirčių skaičius pagal 1.5 × IQR taisyklę:

| Variantas | Išskirčių skaičius |
|---|---:|
| Prieš pildymą | 60 |
| Pildymas vidurkiu | 66 |
| Pildymas mediana | 66 |

### Išvada

Abu pildymo metodai pagrindines `carat` statistikas pakeitė labai mažai.

Kadangi duomenyse yra asimetriškų požymių ir išskirčių, tolesniam bazinių trūkstamų reikšmių pildymui pasirinkta **mediana**, nes ji yra mažiau jautri kraštinėms reikšmėms nei vidurkis.

---

## 24. Bazinių trūkstamų reikšmių užpildymas mediana

Bazinių požymių trūkstamos reikšmės užpildytos šiomis medianomis:

```text
carat = 0.7
depth = 61.7
price = 2385.5
```

Po užpildymo nuo šių bazinių požymių priklausantys išvestiniai požymiai buvo perskaičiuoti.

Po pildymo:

- `carat` – 0 NA;
- `depth` – 0 NA;
- `price` – 0 NA;
- `price_per_carat` – 0 NA;
- `table_depth_ratio` – 0 NA;
- `carat_per_volume` – 3 NA;
- `price_per_volume` – 3 NA.

Likę 3 `NA` yra susiję su trimis originalioje bazėje taip pat egzistuojančiomis `z = 0` reikšmėmis, todėl jų papildomai pildyti nebuvo nuspręsta.

---

## 25. Aprašomoji statistika po trūkstamų reikšmių užpildymo

Po medianos pildymo statistikos buvo perskaičiuotos.

Svarbiausi rezultatai:

| Požymis | Vidurkis | Mediana | SD | Minimumas | Q1 | Q3 | Maksimumas |
|---|---:|---:|---:|---:|---:|---:|---:|
| `carat` | 0.806 | 0.700 | 0.495 | 0.230 | 0.380 | 1.080 | 4.010 |
| `depth` | 61.470 | 61.700 | 1.020 | 43.000 | 61.000 | 62.200 | 65.100 |
| `price` | 4201.755 | 2385.500 | 4584.454 | 348.000 | 974.000 | 5749.250 | 40816.500 |
| `price_per_carat` | 4412.770 | 3542.582 | 5629.600 | 617.143 | 2586.667 | 5154.980 | 131666.129 |
| `table_depth_ratio` | 0.933 | 0.929 | 0.040 | 0.684 | 0.905 | 0.959 | 1.256 |
| `price_per_volume` | 26.831 | 21.601 | 33.981 | 6.938 | 15.620 | 31.543 | 792.743 |

Pagrindinės statistikos po medianos pildymo pasikeitė nedaug, todėl pasirinktas metodas stipriai neiškraipė bendros duomenų struktūros.

---

## 26. Išskirčių analizė po trūkstamų reikšmių pildymo

Po medianos pildymo IQR analizė buvo pakartota.

| Požymis | Išskirčių skaičius | Procentas |
|---|---:|---:|
| `price` | 271 | 6.78 % |
| `price_per_carat` | 145 | 3.62 % |
| `price_per_volume` | 131 | 3.28 % |
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

Po medianos pildymo dalies požymių IQR ribos šiek tiek pasikeitė, todėl kai kurių požymių išskirčių skaičius padidėjo arba sumažėjo.

Tai nereiškia, kad naujai užpildytos reikšmės automatiškai tapo išskirtimis. Pasikeitus kvartiliams ir IQR riboms, dalis anksčiau buvusių kraštinių reikšmių gali patekti už naujų ribų.

Likusių statistinių išskirčių automatiškai nešalinama.


### Išskirčių vertinimas po duomenų sutvarkymo

Po valymo kiekvienam požymiui svarbesniam ir su reikšmingu IQR-išskirčių skaičiumi patikrinta, ar išskirtys atitinka vidines duomenų formules (price = carat·price_per_carat, depth = table/table_depth_ratio) ir ar koreliuoja su logiškai susijusiais požymiais.

depth (113 išskirčių) ir y (2 išskirtys) visiškai atitinka formules ir logiškus ryšius (koreliacija su x = 1,00), todėl laikomos realiomis, retomis reikšmėmis, ne klaidomis.

carat (66 išskirtys) daugiausia yra realūs dideli deimantai (koreliacija su tūriu 0,77), išskyrus vieną eilutę, kurioje volume_xyz = 0 dėl anksčiau paliktos z = 0 neatitikties.

price (271 išskirtis) yra mišri grupė: didžioji dalis — realios didelės kainos, tačiau yra eilučių (mažas carat, price_per_carat > 80 000 €) rodo, kad kai kurios klaidingos kainos.

---

## 27. Mastelio keitimo metodų palyginimas

Kadangi požymių masteliai labai skiriasi, buvo palyginti trys mastelio keitimo metodai:

1. standartizavimas;
2. Min–Max normalizavimas;
3. Robust Scaling.

### 27.1. Standartizavimas

Naudota formulė:

```text
(x - vidurkis) / SD
```

Po standartizavimo `price` požymio:

- vidurkis ≈ 0;
- mediana ≈ -0.396;
- SD = 1.

### 27.2. Min–Max normalizavimas

Naudota formulė:

```text
(x - min) / (max - min)
```

Po Min–Max normalizavimo tiek `carat`, tiek `price` reikšmės pateko į intervalą `[0;1]`.

### 27.3. Robust Scaling

Naudota formulė:

```text
(x - mediana) / IQR
```

Po Robust Scaling `price` požymio:

- vidurkis ≈ 0.380;
- mediana = 0;
- SD ≈ 0.960.

Šis metodas centruoja duomenis pagal medianą ir yra mažiau jautrus kraštinėms reikšmėms.

---

## 28. Mastelio keitimo rezultatų palyginimas

`carat` ir `price` reikšmių ribos po skirtingų metodų:

| Metodas | `carat` min | `carat` max | `price` min | `price` max |
|---|---:|---:|---:|---:|
| Pradiniai duomenys | 0.230 | 4.010 | 348.000 | 40816.500 |
| Standardizavimas | -1.162 | 6.469 | -0.841 | 7.987 |
| Min–Max | 0.000 | 1.000 | 0.000 | 1.000 |
| Robust Scaling | -0.671 | 4.729 | -0.427 | 8.048 |

`price` statistikos:

| Metodas | Vidurkis | Mediana | SD |
|---|---:|---:|---:|
| Pradiniai | 4201.755 | 2385.500 | 4584.454 |
| Standardizavimas | 0.000 | -0.396 | 1.000 |
| Min–Max | 0.095 | 0.050 | 0.113 |
| Robust Scaling | 0.380 | 0.000 | 0.960 |

### Išvada

Visi trys metodai sėkmingai pakeičia požymių mastelį, tačiau jų savybės skiriasi.

Standardizavimas remiasi vidurkiu ir standartiniu nuokrypiu, todėl yra jautresnis stipriai nuo centro nutolusioms reikšmėms.

Min–Max normalizavimas perkelia visas reikšmes į `[0;1]`, tačiau jo rezultatas tiesiogiai priklauso nuo minimumo ir maksimumo.

Robust Scaling remiasi mediana ir IQR, todėl yra atsparesnis išskirtims ir asimetriškiems pasiskirstymams.

Kadangi šioje duomenų aibėje nustatyta nemažai statistinių išskirčių, o `price` ir dalis kitų požymių yra asimetriški, **tolimesniam mastelio keitimui pasirinktas Robust Scaling**.

---

## 29. Pirminio apdorojimo sprendimų santrauka

Iki šio etapo atlikta:

- sutvarkyti netinkami duomenų tipai;
- įvertintos trūkstamos reikšmės;
- patikrinti dublikatai;
- įvertintas klasių balansas;
- nustatytos nelogiškos bazinių požymių reikšmės;
- `carat`, `y`, `depth` ir dalis `price` reikšmių validuotos pagal originalią `ggplot2::diamonds` bazę;
- patikimai atkurtos 89 sugadintos bazinių požymių reikšmės;
- perskaičiuoti išvestiniai požymiai;
- pašalintos `Inf` reikšmės;
- palygintas `carat` pildymas vidurkiu ir mediana;
- bazinių požymių trūkstamos reikšmės užpildytos mediana;
- pakartotinai įvertintos išskirtys;
- palyginti trys mastelio keitimo metodai;
- pasirinktas Robust Scaling.

---
## 30. Požymių ryšių ir koreliacijų analizė

Po duomenų sutvarkymo ir pirminio apdorojimo buvo įvertinti pagrindinių požymių tarpusavio ryšiai.

Analizei naudoti:

- taškiniai grafikai;
- Pearson koreliacijos koeficientas;
- Spearman koreliacijos koeficientas;
- stipriausiai tarpusavyje susijusių požymių paieška.

Pearson koreliacija parodo tiesinio ryšio stiprumą, o Spearman koreliacija vertina monotonišką ryšį ir yra mažiau jautri kraštinėms reikšmėms bei netiesiniam ryšiui.

---

### 30.1. `carat` ir `price` ryšys

Gauti rezultatai:

| Ryšys | Pearson | Spearman |
|---|---:|---:|
| `carat` – `price` | 0.827 | 0.938 |

Abu koeficientai rodo stiprų teigiamą ryšį: didėjant deimanto masei, jo kaina paprastai taip pat didėja.

Spearman koreliacija yra didesnė už Pearson koreliaciją. Tai rodo, kad ryšys tarp `carat` ir `price` yra labai stiprus monotoniškai, tačiau nėra visiškai tiesinis.

---

### 30.2. `volume_xyz` ir `price` ryšys

| Ryšys | Pearson | Spearman |
|---|---:|---:|
| `volume_xyz` – `price` | 0.831 | 0.942 |

Tarp deimanto tūrio ir kainos taip pat nustatytas stiprus teigiamas ryšys.

Kaip ir `carat` atveju, Spearman koreliacija yra didesnė už Pearson. Tai rodo, kad didesnio tūrio deimantai paprastai yra brangesni, tačiau priklausomybė nėra visiškai tiesinė.

---

### 30.3. `carat` ir `volume_xyz` ryšys

| Ryšys | Pearson | Spearman |
|---|---:|---:|
| `carat` – `volume_xyz` | 0.989 | 0.988 |

Šių požymių koreliacija yra beveik lygi 1, todėl tarp deimanto masės ir apskaičiuoto tūrio egzistuoja labai stiprus teigiamas ryšys.

Tai reiškia, kad `carat` ir `volume_xyz` pateikia labai panašią informaciją apie bendrą deimanto dydį.

---

## 31. Stipriausiai koreliuojantys požymiai

Spearman koreliacijų matricoje nustatyta daug labai stiprių ryšių tarp bazinių geometrinių ir išvestinių požymių.

Stipriausių ryšių pavyzdžiai:

| Požymis 1 | Požymis 2 | Spearman koreliacija |
|---|---|---:|
| `dimension_cv` | `depth_ratio` | -1.000 |
| `area_xy` | `y` | 1.000 |
| `area_xy` | `x` | 1.000 |
| `area_yz` | `area_xz` | 0.999 |
| `area_xz` | `volume_xyz` | 0.999 |
| `area_yz` | `volume_xyz` | 0.999 |
| `mean_dimension` | `area_xy` | 0.999 |
| `mean_dimension` | `volume_xyz` | 0.999 |
| `x` | `y` | 0.998 |
| `price_per_volume` | `price_per_carat` | 0.996 |

### 31.1. Geometrinių požymių perteklumas

Labai stipriai tarpusavyje koreliuoja:

- `x`;
- `y`;
- `z`;
- `area_xy`;
- `area_xz`;
- `area_yz`;
- `volume_xyz`;
- `mean_dimension`.

Tai logiška, nes daugelis šių požymių yra tiesiogiai apskaičiuoti iš tų pačių bazinių geometrinių matmenų.

Dėl to vienu metu naudojant visus šiuos požymius modelyje gali atsirasti informacijos dubliavimas.

### 31.2. `price_per_carat` ir `price_per_volume`

Tarp `price_per_carat` ir `price_per_volume` nustatyta labai stipri Spearman koreliacija:

```text
0.996
```

Tai rodo, kad abu požymiai labai panašiai aprašo kainą deimanto dydžio atžvilgiu.

### 31.3. `dimension_cv` ir `depth_ratio`

Tarp `dimension_cv` ir `depth_ratio` nustatyta beveik tobula neigiama Spearman koreliacija:

```text
-1.000
```

Tai rodo, kad didėjant vienam požymiui kitas beveik monotoniškai mažėja.

---

## 32. Pearson ir Spearman rezultatų palyginimas

| Požymių pora | Pearson | Spearman |
|---|---:|---:|
| `carat` – `price` | 0.827 | 0.938 |
| `volume_xyz` – `price` | 0.831 | 0.942 |
| `carat` – `volume_xyz` | 0.989 | 0.988 |

`carat` – `price` ir `volume_xyz` – `price` poroms Spearman koreliacija yra aiškiai didesnė nei Pearson.

Tai leidžia daryti išvadą, kad ryšiai yra labai stiprūs monotoniškai, tačiau ne visiškai tiesiniai.

Tuo tarpu `carat` ir `volume_xyz` atveju Pearson ir Spearman reikšmės beveik vienodos, todėl šių požymių ryšys yra ir labai stiprus, ir artimas tiesiniam.

---

## 33. Koreliacijų analizės išvada

Koreliacijų analizė parodė, kad:

- deimanto dydis yra stipriai susijęs su kaina;
- `carat` ir `volume_xyz` beveik dubliuoja tą pačią dydžio informaciją;
- dauguma geometrinių išvestinių požymių labai stipriai koreliuoja tarpusavyje;
- `price_per_carat` ir `price_per_volume` pateikia labai panašią informaciją;
- kai kurie išvestiniai požymiai gali būti pertekliniai tolimesnei analizei;
- naudojant daug stipriai koreliuojančių požymių vienu metu gali atsirasti multikolinearumo ir informacijos dubliavimo problema.

Todėl prieš taikant mašininio mokymosi ar kitus statistinius metodus verta įvertinti požymių atranką ir, jei reikia, dalį stipriai tarpusavyje koreliuojančių požymių pašalinti arba pasirinkti reprezentatyviausius iš jų.

---
## 34. Galutinis `Ideal` ir `Premium` klasių palyginimas

Po duomenų sutvarkymo, trūkstamų reikšmių užpildymo ir išvestinių požymių perskaičiavimo buvo pakartotinai palygintos `Ideal` ir `Premium` klasės.

Abiejose klasėse yra po 2000 objektų, todėl klasės išlieka visiškai subalansuotos.

### 34.1. Pagrindinių požymių statistika pagal klasę

| Požymis | Ideal vidurkis | Ideal mediana | Premium vidurkis | Premium mediana |
|---|---:|---:|---:|---:|
| `carat` | 0.707 | 0.550 | 0.904 | 0.820 |
| `depth` | 61.7 | 61.8 | 61.2 | 61.4 |
| `table` | 55.9 | 56.0 | 58.7 | 59.0 |
| `price` | 3699 | 1851 | 4705 | 3040 |
| `volume_xyz` | 116 | 89.6 | 147 | 141 |
| `price_per_carat` | 4428 | 3358 | 4397 | 3778 |

---

### 34.2. `carat` skirtumai tarp klasių

`Premium` klasės deimantai pagal `carat` yra didesni.

Medianinė reikšmė:

```text
Ideal   = 0.55
Premium = 0.82
```

Vidurkiai taip pat rodo tą pačią tendenciją:

```text
Ideal   = 0.707
Premium = 0.904
```

Tai rodo, kad šiame rinkinyje `Premium` klasėje dažniau pasitaiko didesnės masės deimantų.

---

### 34.3. `volume_xyz` skirtumai

Tūrio skirtumas tarp klasių taip pat aiškus.

Medianinė `volume_xyz` reikšmė:

```text
Ideal   = 89.6
Premium = 141
```

Vidurkiai:

```text
Ideal   = 116
Premium = 147
```

Tai atitinka `carat` rezultatus ir patvirtina, kad `Premium` klasės objektai šiame rinkinyje vidutiniškai yra didesni.

---

### 34.4. `price` skirtumai

`Premium` klasėje kainos yra aukštesnės.

Medianinė kaina:

```text
Ideal   = 1851
Premium = 3040
```

Vidutinė kaina:

```text
Ideal   = 3699
Premium = 4705
```

Kadangi abiejose klasėse vidurkis yra gerokai didesnis už medianą, kainų pasiskirstymai išlieka asimetriški į dešinę.

---

### 34.5. `table` ir `depth` skirtumai

`table` požymis tarp klasių skiriasi aiškiau nei `depth`.

Medianinė `table` reikšmė:

```text
Ideal   = 56
Premium = 59
```

Tuo tarpu medianinis `depth`:

```text
Ideal   = 61.8
Premium = 61.4
```

Tai rodo, kad `depth` skirtumas tarp klasių yra nedidelis, o `table` požymis klasėse skiriasi labiau.

---

### 34.6. `price_per_carat` skirtumai

Medianinė `price_per_carat` reikšmė:

```text
Ideal   = 3358
Premium = 3778
```

Tačiau vidurkiai yra labai panašūs:

```text
Ideal   = 4428
Premium = 4397
```

Tai rodo, kad šio požymio pasiskirstymui didelę įtaką daro aukštos kraštinės reikšmės, todėl mediana yra informatyvesnė apibūdinant tipinę reikšmę.

---

## 35. Klasių palyginimo išvada

Galutinis `Ideal` ir `Premium` palyginimas parodė, kad:

- klasės yra visiškai subalansuotos: po 2000 objektų;
- `Premium` klasėje deimantai yra didesni pagal `carat` ir `volume_xyz`;
- `Premium` klasėje medianinė ir vidutinė kaina yra didesnė;
- `table` požymis `Premium` klasėje yra aukštesnis;
- `depth` skirtumas tarp klasių yra nedidelis;
- `price_per_carat` medianos tarp klasių skiriasi, tačiau vidurkiai yra labai panašūs.

Tai rodo, kad klasės skiriasi ne tik pagal klasės etiketę, bet ir pagal kelias svarbias fizines bei kainos charakteristikas.

---
## 36. Duomenų rinkinio tinkamumo tolesnei analizei vertinimas

Po visų atliktų duomenų kokybės tikrinimo, validavimo ir pirminio apdorojimo etapų buvo įvertinta galutinė duomenų rinkinio būklė.

Galutinė rinkinio suvestinė:

| Rodiklis | Reikšmė |
|---|---:|
| Objektų skaičius | 4000 |
| Požymių skaičius | 20 |
| `Ideal` objektų skaičius | 2000 |
| `Premium` objektų skaičius | 2000 |
| Dublikatų skaičius | 0 |
| Likusių `NA` skaičius | 6 |

Klasės yra visiškai subalansuotos, todėl klasifikavimo uždaviniuose nereikėtų papildomai spręsti klasių disbalanso problemos.

---

### 36.1. Galutinė loginių reikšmių patikra

Po visų atliktų korekcijų bazinių požymių loginė patikra parodė:

| Tikrinimas | Kiekis |
|---|---:|
| `carat <= 0` | 0 |
| `price <= 0` | 0 |
| `x <= 0` | 0 |
| `y <= 0` | 0 |
| `z <= 0` | 3 |
| `depth <= 0` | 0 |
| `table <= 0` | 0 |

Trys `z = 0` atvejai nebuvo koreguoti, nes tokios reikšmės egzistuoja ir originalioje `ggplot2::diamonds` bazėje.

Dėl jų `volume_xyz = 0`, todėl dviejuose išvestiniuose požymiuose dalyba negalima:

- `carat_per_volume` – 3 `NA`;
- `price_per_volume` – 3 `NA`.

Šios reikšmės nebuvo dirbtinai pildomos, nes tai sukurtų nepagrįstą informaciją.

---

### 36.2. Duomenų rinkinio stiprybės

Pagrindinės rinkinio stiprybės:

- pakankamai didelis objektų skaičius – 4000;
- klasės visiškai subalansuotos;
- nėra dublikatų;
- dauguma sugadintų bazinių reikšmių buvo sėkmingai identifikuotos ir atkurtos;
- trūkstamų bazinių reikšmių dalis buvo nedidelė;
- išvestiniai požymiai buvo perskaičiuoti po bazinių duomenų koregavimo;
- liko labai mažai trūkstamų reikšmių;
- duomenyse yra tiek bazinių, tiek išvestinių geometrinių ir kainos požymių;
- nustatyti aiškūs ryšiai tarp dydžio, tūrio ir kainos;
- `Ideal` ir `Premium` klasės skiriasi pagal kelis svarbius požymius.

Šios savybės leidžia duomenis naudoti tolimesnei statistinei analizei ir mašininio mokymosi metodams.

---

### 36.3. Duomenų rinkinio apribojimai

Nepaisant atlikto sutvarkymo, rinkinyje išlieka keli apribojimai.

#### 1. Likusios 11 nevienareikšmių `price` reikšmių

Iš 60 aiškiai sugadintų `price` reikšmių 49 buvo vienareikšmiškai atkurtos, tačiau 11 atvejų originalioje bazėje buvo keli galimi atitikmenys.

Kadangi nebuvo patikimo pagrindo pasirinkti vieną konkrečią reikšmę, šios 11 kainų buvo paliktos nepakeistos.

Todėl jos gali turėti įtakos:

- kainos vidurkiui;
- kainos standartiniam nuokrypiui;
- kainos išskirčių skaičiui;
- nuo kainos priklausantiems išvestiniams požymiams.

#### 2. Trys `z = 0` atvejai

Šie atvejai egzistuoja originalioje duomenų bazėje, tačiau fiziškai tokia deimanto aukščio reikšmė yra problemiška.

Dėl jų:

- `volume_xyz = 0`;
- `carat_per_volume` negali būti apskaičiuojamas;
- `price_per_volume` negali būti apskaičiuojamas.

#### 3. Daug stipriai koreliuojančių požymių

Geometriniai išvestiniai požymiai labai stipriai koreliuoja tarpusavyje.

Pavyzdžiui, `carat`, `volume_xyz`, `area_xy`, `area_xz`, `area_yz`, `mean_dimension`, `x`, `y` ir `z` dalinai dubliuoja tą pačią dydžio informaciją.

Todėl prieš kuriant kai kuriuos modelius reikėtų atlikti požymių atranką, kad būtų sumažintas multikolinearumas ir informacijos dubliavimas.

#### 4. Išskirtys

Po duomenų sutvarkymo vis dar liko statistinių išskirčių, ypač:

- `price`;
- `price_per_carat`;
- `price_per_volume`;
- `dimension_cv`;
- `depth_ratio`;
- `depth`.

Jos nebuvo automatiškai šalinamos, nes dalis jų gali būti realūs reti stebiniai.

---

### 36.4. Tinkamumas mašininiam mokymuisi

Duomenų rinkinys yra tinkamas tolimesniems mašininio mokymosi eksperimentams, tačiau prieš konkretų modeliavimą reikėtų atsižvelgti į metodo reikalavimus.

Jei būtų taikomi metodai, jautrūs požymių masteliui, būtų tikslinga naudoti anksčiau pasirinktą **Robust Scaling**.

Jei būtų taikomi metodai, jautrūs stipriai koreliuojantiems požymiams, reikėtų atlikti požymių atranką ir neįtraukti visų beveik identišką informaciją turinčių geometrinių požymių vienu metu.

Kadangi klasės `Ideal` ir `Premium` yra vienodo dydžio, papildomas klasių balansavimas nėra reikalingas.

---

## 37. Galutinės darbo išvados

Atlikus pirminę duomenų aibės analizę ir paruošimą tyrimui, galima suformuluoti šias pagrindines išvadas:

1. Pradinę duomenų aibę sudarė 4000 objektų ir 20 požymių. Tikslinė klasė turėjo dvi visiškai subalansuotas reikšmes: `Ideal` ir `Premium`, po 2000 objektų kiekvienoje klasėje.

2. Pradinėje duomenų aibėje buvo nustatyta trūkstamų reikšmių, netinkamų duomenų tipų ir nelogiškų bazinių reikšmių.

3. Validuojant duomenis pagal originalią `ggplot2::diamonds` bazę buvo patikimai atkurtos 89 sugadintos bazinių požymių reikšmės:
   - 14 `carat`;
   - 13 `y`;
   - 13 `depth`;
   - 49 `price`.

4. Dar 11 aiškiai įtartinų `price` reikšmių nepavyko atkurti vienareikšmiškai, todėl jos nebuvo keičiamos. Tai laikoma vienu pagrindinių galutinio rinkinio apribojimų.

5. Trys `z = 0` atvejai buvo palikti, nes jie egzistuoja originalioje duomenų bazėje. Dėl jų galutiniame rinkinyje liko 6 `NA` reikšmės: po 3 `carat_per_volume` ir `price_per_volume` požymiuose.

6. Trūkstamų bazinių reikšmių pildymui buvo palygintas vidurkio ir medianos metodas. Kadangi duomenyse yra asimetriškų pasiskirstymų ir išskirčių, pasirinktas pildymas mediana.

7. Palyginus standartizavimą, Min–Max normalizavimą ir Robust Scaling nustatyta, kad šiai duomenų aibei tinkamiausias yra Robust Scaling, nes jis yra mažiau jautrus išskirtims.

8. Koreliacijų analizė parodė stiprų ryšį tarp deimanto dydžio ir kainos. `carat` ir `price` Spearman koreliacija buvo 0.938, o `volume_xyz` ir `price` – 0.942.

9. Tarp daugelio geometrinių bazinių ir išvestinių požymių nustatytos labai stiprios koreliacijos, todėl dalis jų gali būti pertekliniai tolimesniam modeliavimui.

10. `Premium` klasės deimantai šiame rinkinyje vidutiniškai ir pagal medianą yra didesni bei brangesni už `Ideal` klasės deimantus. Ryškesni skirtumai nustatyti pagal `carat`, `volume_xyz`, `price` ir `table` požymius.

11. Galutinėje duomenų aibėje nėra dublikatų, klasės yra subalansuotos, o didžioji dalis aptiktų kokybės problemų buvo išspręsta.

12. Duomenų rinkinys laikomas tinkamu tolimesnei statistinei analizei ir mašininio mokymosi eksperimentams, tačiau prieš modeliavimą reikėtų atsižvelgti į likusias 11 įtartinų kainos reikšmių, tris `z = 0` atvejus ir stiprų dalies požymių tarpusavio koreliavimą.

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
| Patikimai atkurtos sugadintos reikšmės | 89 |
| Nevienareikšmiškai atkuriamos `price` reikšmės | 11 |
| `z = 0` atvejai | 3 |


# Tolimesni analizės žingsniai

Toliau lieka:

1. įvertinti bendrą duomenų rinkinio tinkamumą tolesnei analizei;
2. apibendrinti pagrindinius rinkinio privalumus ir apribojimus;
3. įvertinti, ar duomenų kokybė yra pakankama mašininio mokymosi metodams;
4. suformuluoti galutines darbo išvadas.
