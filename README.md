# A02 deimantų dimensijos mažinimas

Šiame projekte atliekamas daugiamačių duomenų(A02 aibės) dimensijos mažinimas. Šis darbas pradedamas su po pirminio apdorojimo sutvarkyta duomenų aibe.
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

Duomenų būklė po pirmojo darbo:

| Charakteristika | Galutinė reikšmė |
|---|---:|
| Objektai | 4000 |
| Požymiai | 20 |
| Ideal | 2000 |
| Premium | 2000 |
| Dublikatai | 0 |
| Likę NA | 0 |

---

# 3 skirtingos aibės

## Originali

Palikta aibė po pirmojo darbo, sutvarkius duomenis(tipų taisymas, nelogiškų reikšmių atkūrimas pagal
originalią `ggplot2::diamonds` bazę, trūkstamų reikšmių užpildymas mediana,
išvestinių požymių perskaičiavimas).

## Be koreliuotų požymių

Šalinimo kriterijus: |Spearman r| ≥ 0,90 su paliekamu požymiu, o šalinamas
požymis neneša naujos informacijos (yra to paties požymio perskaičiavimas arba
matuoja tą patį dalyką). Naudotas Spearman koeficientas, nes požymiai
asimetriški.

| Pašalintas požymis | Paliktas požymis | Spearman r | Pagrindimas |
|---|---|---|---|
| `x` | `carat` | 0,991 | Matmuo, matuoja deimanto dydį kaip ir `carat` |
| `y` | `carat` | 0,990 | Tas pats |
| `z` | `carat` | 0,988 | Tas pats |
| `volume_xyz` | `carat` | 0,991 | Išvestas iš `x·y·z` |
| `area_xy` | `carat` | 0,991 | Išvestas iš `x·y` |
| `area_xz` | `carat` | 0,990 | Išvestas iš `x·z` |
| `area_yz` | `carat` | 0,990 | Išvestas iš `y·z` |
| `mean_dimension` | `carat` | 0,992 | Išvestas iš `(x+y+z)/3` |
| `depth_ratio` | `depth` | 0,990 | `depth` perskaičiavimas pagal formulę |
| `dimension_cv` | `depth` | -0,990 | Su `depth_ratio` koreliuoja -0,99997 |
| `price_per_carat` | `price` | 0,943 | Išvestas iš `price / carat` |
| `price_per_volume` | `price` | 0,947 | Išvestas iš `price / volume_xyz`; su `price_per_carat` r = 0,996 |
| `table_depth_ratio` | `table` | 0,941 | Išvestas iš `table / depth` |

Palikti 7 požymiai: `carat`, `depth`, `table`, `price`, `length_width_ratio`,
`carat_per_volume`, `class`.

Deimanto formą ir toliau nusako `length_width_ratio` (x/y), kuris su kitais
požymiais koreliuoja silpnai (didžiausia |r| ≈ 0,32).

`carat` ir `price` (r = 0,948) palikti abu: tai pagrindinis ryšys duomenyse,
o `price` nėra išvedamas iš `carat` taip, kaip tūris iš `x`, `y`, `z`.

## Be ektremumų

Ekstremumu laikoma reikšmė už ribų [Q1 − 3·IQR ; Q3 + 3·IQR]. Ekstremumai
ieškomi visuose 19 skaitinių požymių, o eilutė šalinama, jei ekstremumas yra
bent viename iš jų.

| Požymis | Ekstremumų kiekis | % |
|---|---|---|
| `carat_per_volume` | 61 | 1,52 |
| `price_per_carat` | 15 | 0,38 |
| `price_per_volume` | 8 | 0,20 |
| `carat` | 3 | 0,07 |
| `volume_xyz` | 3 | 0,07 |
| `depth_ratio` | 3 | 0,07 |
| `dimension_cv` | 3 | 0,07 |
| `table_depth_ratio` | 2 | 0,05 |
| `depth` | 1 | 0,03 |
| `table` | 1 | 0,03 |
| `price`, `x`, `y`, `z`, `area_xy`, `area_xz`, `area_yz`, `length_width_ratio`, `mean_dimension` | 0 | 0,00 |

Ekstremumų kiekių suma (100) didesnė už pašalintų eilučių skaičių (72), nes
vienoje eilutėje ekstremumų gali būti keliuose požymiuose iš karto (pvz.,
`carat`, `volume_xyz` ir `depth_ratio` ekstremumai dažnai sutampa toje pačioje eilutėje).

**Rezultatas:** pašalinta 72 eilutės (1,80 %), liko 3928 iš 4000.

Daugiausia ekstremumų (61 iš 100) yra išvestiniame požymyje `carat_per_volume`.
Baziniuose požymiuose `price`, `x`, `y`, `z` ekstremumų nėra, todėl pašalintos
eilutės daugiausia išsiskiria santykiniais, o ne pagrindiniais matmenimis ar kaina.