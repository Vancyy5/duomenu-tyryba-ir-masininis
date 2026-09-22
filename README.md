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

# Tolimesni analizės žingsniai

Toliau planuojama:

1. patikrinti likusias labai neįprastas bazinių požymių reikšmes, ypač `depth` ekstremumus;
2. pasirinkti tinkamą trūkstamų reikšmių apdorojimo metodą;
3. įvertinti, kurios statistinės išskirtys yra realios, o kurios gali būti klaidos;
4. atlikti palyginamąjį normavimo / standartizavimo eksperimentą;
5. tirti ryšius tarp:
   - `carat` ir `price`;
   - `volume_xyz` ir `price`;
   - `carat` ir `volume_xyz`;
6. atlikti koreliacijų analizę;
7. nustatyti stipriai tarpusavyje susijusius bazinius ir išvestinius požymius;
8. įvertinti, ar duomenų rinkinys tinkamas tolimesnei analizei ir mašininio mokymosi metodams.
