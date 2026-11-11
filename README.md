# EHDV-8 bioeconomic model — French beef cow–calf farms

## Overview

This repository contains the R code and configuration files used to estimate farm-level economic losses associated with epizootic haemorrhagic disease (EHDV-8) in French beef cow–calf production systems during the 2023–2024 outbreak.

The model compares an EHD-free reference scenario with an EHD-affected scenario, accounting for changes in cow mortality, pre-weaning calf mortality, calving interval, veterinary treatment costs and sanitary restriction-related costs.

Economic outcomes are expressed as annual gross margin and gross-margin losses per breeding cow.

## Main files

- `BIOECO_public.qmd` — main Quarto document, simulations, sensitivity analyses and figures.
- `R/06.modele_funs.R` — bioeconomic model equations and functions.
- `R/08.scenarios2.R` — parameter loading and scenario preparation, including the deterministic scenario grid.
- `R/sens_restr.R` — sensitivity analysis of restriction-related costs.
- `docs/journal_choix.md` — documentation of modelling and parameterisation decisions.

## Configuration files

- `config/params_base2.yaml` — baseline herd and economic parameters.
- `config/impacts_mhe.yaml` — EHD-related changes in mortality and calving interval.
- `config/params_restr.yaml` — central values for sanitary restriction-related costs.
- `config/stochastic_2023_2.csv` — parameter distributions used in Monte Carlo simulations.
- `config/scenarios_grid.csv` — deterministic scenario grid retained for compatibility with the scenario-loading script.

## Simulations

The main analysis uses 2,000 Monte Carlo iterations with a fixed random seed (`42`).

Within each iteration, the EHD-free and EHD scenarios share the same sampled baseline parameters, allowing paired comparisons.

The model assumes a constant herd size and internal replacement, with the reference replacement rate maintained across scenarios.

The main analysis includes restriction-related costs. Additional sensitivity analyses explore alternative market price reductions, PCR testing proportions, disease severity and weanling prices.

## Reproducing the analysis

The analysis requires R, Quarto and the R packages used by the scripts. Some graphical outputs also require Pandoc and additional rendering dependencies.

From the repository root, run:

```bash
quarto render BIOECO_public.qmd
```

For the main analysis, ensure that restriction-related costs are enabled (`restr: true`).

The document generates results and figures in `sorties/figures/`.

## Data availability

The repository contains model code, aggregated input parameters and scenario configurations. Individual herd-level epidemiological and administrative data used to derive some model inputs are not included.

The model can be executed using the supplied configuration files without access to these individual-level data.

## Scope

The model estimates disease-associated farm-level economic losses over a one-year horizon. It does not include public-sector costs, compensation payments or economic losses incurred by non-infected farms.


## Citation

If you use this model in your research, please cite the archived software version:

Heckly, P.-A. (2026). *EHDV-8 bioeconomic model for French beef cow–calf farms* (Version 1.0.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.24144287

The DOI identifies the exact version of the model used in the analysis. The repository also provides a `CITATION.cff` file containing machine-readable citation metadata.
