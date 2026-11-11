## Current model configuration

The main analysis reported in the manuscript includes sanitary restriction-related costs (`restr: true`).

The final parameter values are:

| Parameter | Value |
|---|---:|
| `PRICEREDUCTION` | €60/weanling sold |
| `D_BLOCKMEAN` | 5.4 days |
| `COSTDAY` | €1/weanling/day |
| `PRICEPCR` | €15/test |
| `PROPPCR` | 0.71 |

Restriction-related parameters are treated as fixed within each Monte Carlo simulation. Their uncertainty is explored through separate deterministic sensitivity analyses.

The dated entries below document the development of the model. Some historical values and configurations have subsequently been superseded and should not be interpreted as parameters of the final analysis.

---

# Journal des choix

Trace des décisions de modèle (mécanique vs paramètres), datée.
Les noms YAML / tables doivent rester alignés avec le code (voir README).

## 2026-09-27 — PRICEREDUCTION = 60 et sensibilité one-way

### Mécanique

- Valeur principale de `PRICEREDUCTION` : **60** €/broutard vendu (effet de marché moyen sur la période, distinct du pic ~200 €).
- Pas de distribution sur `PRICEREDUCTION` ni `PROPPCR`. Pas de scénario à 200 €.
- Cinq scénarios déterministes, un paramètre à la fois, **mêmes tirages MC** (seed 42) : on recalcule `COST_*` à partir de `n_WEAN_sold` de chaque tirage.
- Coût unitaire principal : `60 + 1×5.4 + 0.71×15 = 76.05` € / broutard.

### Scénarios

| Scénario | PRICEREDUCTION | PROPPCR |
|---|---|---|
| No average price effect | 0 | 0.71 |
| Main analysis | 60 | 0.71 |
| High price effect | 100 | 0.71 |
| PCR proportion - low | 60 | 0.40 |
| PCR proportion - high | 60 | 0.80 |

### Fichiers

- `config/params_restr.yaml`, `R/06.modele_funs.R`, `R/sens_restr.R`, BIOECO_public.qmd`

## 2026-09-27 — Bascule COST_RESTR (core off / variante on)

### Mécanique

- Défaut = V11 **core** : `COST_RESTR = 0` dans EHD-free **et** EHD (`restr: false`).
- Variante : `quarto render 11.BIOECO_2.qmd -P restr:true`. Les cinq paramètres sont copiés sur le scénario EHD uniquement via `apply_mhe_restr()`.
- Équations (pas de `PROPAFFECTED` / `PROPBLOCKED`) :

`COST_PRIX = n_WEAN_sold × PRICEREDUCTION`

`COST_BLOC = n_WEAN_sold × COSTDAY × D_BLOCKMEAN`

`COST_PCR  = n_WEAN_sold × PROPPCR × PRICEPCR`

`COST_RESTR = COST_PRIX + COST_BLOC + COST_PCR`

- `n_WEAN_sold` = broutards mâles + femelles vendus / vache-année. Réformes (`REV_COW`) hors de ce poste.
- Les cinq paramètres **ne sont pas** tirés dans le Monte Carlo (incertitude surtout épistémique). `COST_RESTR` peut quand même varier via `n_WEAN_sold`.
- Sensibilité déterministe ultérieure : `overrides = list(PRICEREDUCTION = 50)` (ou 200) / YAML `config/params_restr.yaml`. Pas de Uniform(50, 200).

### Paramètres (centraux, EHD seulement si `restr` on)

| Nom | Valeur | Unité |
|---|---|---|
| `PRICEREDUCTION` | 100 | € / broutard vendu |
| `D_BLOCKMEAN` | 5.4 | jours / broutard vendu |
| `COSTDAY` | 1 | € / broutard / jour |
| `PRICEPCR` | 15 | € / broutard testé |
| `PROPPCR` | 0.71 | proportion testée |

Coût unitaire : `100 + 1×5.4 + 0.71×15 = 116.05` € / broutard vendu.

### Fichiers

- `R/06.modele_funs.R`, `R/08.scenarios2.R`, `11.BIOECO_2.qmd`
- `config/params_base2.yaml` (zéros), `config/params_restr.yaml` (centraux)
- `tests/test_costrestr.R`

## 2026-09-26 — Maintien des broutards (`COST_BLOC`)

### Mécanique

- Le poste restrictions reste `COST_RESTR = COST_PRIX + COST_BLOC + COST_PCR` (€ / vache / an).
- `COST_PRIX` et `COST_PCR` : inchangés (eq. 6 et 8).
- `COST_BLOC` (eq. 7) : `n_WEAN_sold × COSTDAY × D_BLOCKMEAN`.
- `SH_BLOCK` (`PROPBLOCKED`) est retiré du calcul : `D_BLOCKMEAN` est déjà une moyenne sur **tous** les broutards vendus (y compris sans retard). Le garder aurait compté deux fois la part retardée.
- `n_WEAN_sold` = mâles + femelles vendus par vache et par an.
- Hypothèse : le retard moyen est estimé sur les broutards **mâles** et appliqué aussi aux **femelles** vendues.
- Scénario référence : `COSTDAY = 0` et `D_BLOCKMEAN = 0` (YAML). Le forçage MHE pose les valeurs ponctuelles ci-dessous.
- Ce poste reste **déterministe** : pas d’entrée dans `config/stochastic_2023_2.csv`.

### Paramètres

| Nom | Valeur MHE | Unité | Statut |
|---|---|---|---|
| `COSTDAY` | 1 | € / jour / broutard | ponctuel, déterministe |
| `D_BLOCKMEAN` | 10 | jours moyens / broutard vendu | ponctuel, déterministe |

### Test numérique

`n_WEAN_sold = 0,5` ; `COSTDAY = 1` ; `D_BLOCKMEAN = 10` → `COST_BLOC = 5` € / vache / an.

### Fichiers

- `R/06.modele_funs.R` (moteur V11)
- `R/08.scenarios2.R`, `11.BIOECO_2.qmd` (forçage MHE)
- `config/params_base2.yaml` (et YAML de référence)
- moteurs / scénarios antérieurs alignés pour la même formule

## 2026-09-26 — Sortie des graphiques en PNG

### Mécanique

- Tous les graphiques ggplot du qmd sont rendus en PNG (`fig-format: png`, dossier relatif `sorties/figures/`) **et** restent affichés dans le HTML (`embed-resources`).
- Chemin **relatif** (pas `here()` absolu), pour que Quarto retrouve les images dans le rapport.
- Les Sankey `networkD3` restent interactifs dans le HTML ; un PNG est aussi écrit si `webshot2` est disponible.

### Paramètres

- Résolution : 200 dpi.
- Dossier : `sorties/figures/`.

