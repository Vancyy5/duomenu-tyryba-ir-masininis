# A02 deimantų klasterizavimas

Šiame projekte atliekamas daugiamačių duomenų(A02 aibės) klasterizavimas. Šis darbas pradedamas su po pirminio apdorojimo sutvarkyta duomenų aibe.
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

## Penkios duomenų aibės

1. aibe_orig  - originali, be dimensijos mažinimo
2. aibe_pca5  - PCA, 5 komponentės          
3. aibe_pca2  - PCA, 2 komponentės          
4. aibe_tsne5 - t-SNE, 5 dimensijos         
5. aibe_tsne2 - t-SNE, 2 dimensijos         

aibe_orig atitinka aibe C antrame darbe, t. y. be iššimčių ir turi likusius 3928 objektus.