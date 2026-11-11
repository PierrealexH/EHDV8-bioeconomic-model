
#scenarios pour analyse de sensibilité du modele bio-eco
#V6 : lecture des paramètres selon CSV

#V8 cherche params_base2 qui contient taux mortalité vache à 2%

library(yaml)
library(here)

# lecture des yaml ; récupére source et chemin pour afficher dans quarto
read_yaml_list <- function(path) {
  full <- here::here(path)
  y <- yaml::read_yaml(full)
  
  # Si ce n'est pas une liste, on convertit proprement
  if (!is.list(y)) {
    # vecteur nommé -> liste nommée
    if (!is.null(names(y))) y <- as.list(y) else
      stop("Le YAML n'est ni une mapping (clé: valeur) ni un vecteur nommé : ", full)
  }
  
  # garde le chemin en attribut (ne pollue pas la liste)
  attr(y, "source_file") <- normalizePath(full, winslash = "/")
  y
}



get_yaml_source <- function(x) {
  # récupère la source
  s <- attr(x, "source_file", exact = TRUE)
  if (is.null(s) && !is.null(x$`_source_file`)) s <- x$`_source_file`
  if (is.null(s)) s <- "<inconnu>"
  s
}
basename_yaml <- function(x) {
  s <- attr(x, "source_file", exact = TRUE)
  if (is.null(s) && !is.null(x$`_source_file`)) s <- x$`_source_file`
  if (is.null(s)) return("<inconnu>")
  basename(s)  # ne garde que le nom du fichier
}



####.  ICI CHARGEMENT DE YAML   ######

#CHEMIN LECTURE YAML (à modifier si autre jeu de paramètres)
# Ne pas nommer cette liste `params` : sous Quarto ce binding est verrouillé
# (YAML du document, ex. restr).
params_eco  <- read_yaml_list("config/params_base2.yaml")
impacts_mhe <- read_yaml_list("config/impacts_mhe.yaml")

if (!exists("restr_on")) restr_on <- FALSE
restr_yml <- here::here("config/params_restr.yaml")
if (file.exists(restr_yml)) {
  extra <- read_yaml_list("config/params_restr.yaml")
  extra <- extra[intersect(names(extra), names(restr_params_central))]
  if (length(extra)) restr_params_central <- modifyList(restr_params_central, extra)
}

#PARAMS MHE : traitements + éventuellement COST_RESTR (bascule restr_on)
params_mhe <- apply_impacts(params_eco, impacts_mhe)
params_mhe$COST_VET_D <- 15
params_mhe <- apply_mhe_restr(params_mhe, restr = restr_on)




# --- 0) Charger la grille (CSV complet : 1 ligne = 1 scénario) ---
grid <- read.csv(here::here("config/scenarios_grid.csv"), stringsAsFactors = FALSE)

# --- 1) Helper : convertir une ligne de grille -> liste params attendue par le moteur
row_to_params <- function(row, base_params) {
  p <- base_params
  
  # Colonnes attendues dans la grille (complète)
  p$CULL            <- row$CULL
  p$MO_COW         <- row$MO_COW
  p$IVV              <- row$IVV
  p$MO_WEAN          <- row$MO_WEAN
  p$PR_MA            <- row$PR_MA
  p$PRICE_CULL        <- row$PRICE_CULL
  p$PRICE_WEANM        <- row$PRICE_WEANM
  p$PRICE_WEANF        <- row$PRICE_WEANF
  p$cout_alim_ugb    <- row$cout_alim_ugb
  p$cout_elevage_ugb <- row$cout_elevage_ugb
  p$ugb_by_cow       <- row$ugb_by_cow
  
  p
}

# --- 2) Exécuter tous les scénarios de la grille (impacts MHE constants) ---
run_one <- function(row_df) {
  row <- row_df[1, , drop = FALSE]
  
  # a) paramètres du scénario (à partir de la grille)
  p_ref <- row_to_params(row, params_eco)
  
  # b) TR_eff_ref : CALCULÉ POUR CETTE LIGNE uniquement
  TR_eff_ref_row <- p_ref$CULL + p_ref$MO_COW
  
  # c) scénario REF (TR_eff_ref_row appliqué)
  res_ref <- run_scenario(p_ref, TR_eff_ref_row, mhe = FALSE)
  
  # d) scénario MHE : impacts constants puis surcoûts (TR_eff_ref_row reste le même)
  p_mhe <- apply_impacts(p_ref, impacts_mhe)
  p_mhe$COST_VET_D <- 15
  p_mhe <- apply_mhe_restr(p_mhe, restr = restr_on)
  
  res_mhe <- run_scenario(p_mhe, TR_eff_ref_row, mhe = TRUE)
  
  # e) petit résumé
  data.frame(
    scenario = if ("name" %in% names(row)) row$name else NA_character_,
    TR_eff_ref = TR_eff_ref_row,
    MB_ref   = res_ref$MB_op,
    MB_mhe   = res_mhe$MB_op,
    dMB      = res_mhe$MB_op - res_ref$MB_op,
    stringsAsFactors = FALSE
  )
}

results_df <- do.call(rbind, lapply(split(grid, seq_len(nrow(grid))), run_one))
print(results_df)

# Alias hors Quarto (Rscript / tests). Sous Quarto, `params` reste le YAML du document.
if (!(exists("params", inherits = FALSE) && bindingIsLocked("params", environment()))) {
  params <- params_eco
}



