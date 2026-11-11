## coeur de modele 02 : distinction broutards par sexe
## modèle 03 :
  #TR_eff est calculé une seule fois à partir des paramètres de référence et réutilisé pour le scénario MHE.
  #On supprime l’impact dCULL (plus d’édition de CULL dans apply_impacts).
  #Dans le scénario MHE uniquement, on calcule CULL_used = TR_eff_ref – MO_COW_mhe.
  #Les ventes femelles restent calculées avec TR_eff_ref (constant).
## modele 04 : idem 03
## modele 05 : calcule les cout alim et elevage à la vache à partir de valeur par ugb
      #ajout de ugb_by_cow dans les paramètres,
      #remplacement de cout_alim par cout_alim_ugb,
      #remplacement de cout_elevage par cout_elevage_ugb,
      #calcul dans le moteur :
      # cout_alim = cout_alim_ugb * ugb_by_cow
      # cout_elevage = cout_elevage_ugb * ugb_by_cow.
#modèle 06 : pour tourner avec qmd analyse de sensibilité, a priori idem 05



# --- Fonctions cœur ---
# "fusible" contre valeurs calculées négatives
check_nonneg <- function(x, name) {
  if (any(x < 0)) warning(name, " < 0 : résultat tronqué à 0.")
  pmax(x, 0)
}

#---------------------  REVENU
REV_COW <- function(CULL, PRICE_CULL) CULL * PRICE_CULL

# n_WEAN_sold par sexe : les mâles ne participent pas au renouvellement
split_weaned <- function(n_weaned, PR_MA){
  n_m <- PR_MA * n_weaned
  n_f <- (1 - PR_MA) * n_weaned
  list(n_weaned_m = n_m, n_weaned_f = n_f)
}

sold_by_sex <- function(n_weaned_m, n_weaned_f, TR_eff){
  if (TR_eff > n_weaned_f) warning("TR_eff > n_weaned_f : vérifie les entrées (renouvellement > femelles sevrées).")
  n_sold_m <- n_weaned_m                 # tous les mâles partent en broutards
  n_sold_f <- check_nonneg(n_weaned_f - TR_eff, "n_WEAN_sold_f")
  list(n_WEAN_sold_m = n_sold_m, n_WEAN_sold_f = n_sold_f)
}

REV_WEAN <- function(n_WEAN_sold_m, n_WEAN_sold_f, PRICE_WEANM, PRICE_WEANF){
  rev_m <- n_WEAN_sold_m * PRICE_WEANM
  rev_f <- n_WEAN_sold_f * PRICE_WEANF
  list(total = rev_m + rev_f, rev_m = rev_m, rev_f = rev_f)
}

#--------------------COUTS DE PRODUCTION
COST_PROD <- function(cout_alim, cout_elevage) cout_alim + cout_elevage

COST_PRIX <- function(n_WEAN_sold, pricereduction) n_WEAN_sold * pricereduction
COST_BLOC <- function(n_WEAN_sold, costday, d_blockmean) n_WEAN_sold * costday * d_blockmean
COST_PCR  <- function(n_WEAN_sold, proppcr, pricepcr) n_WEAN_sold * proppcr * pricepcr

# Valeurs centrales MHE du poste restrictions (déterministes ; pas dans le CSV stochastique).
# Surcharge possible : apply_mhe_restr(p, restr = TRUE, overrides = list(PRICEREDUCTION = 50))
restr_params_central <- list(
  PRICEREDUCTION = 60,
  COSTDAY        = 1,
  D_BLOCKMEAN    = 5.4,
  PRICEPCR       = 15,
  PROPPCR        = 0.71
)

p_num <- function(p, keys, default = 0) {
  for (nm in keys) {
    if (!is.null(p[[nm]]) && !is.na(p[[nm]])) return(p[[nm]])
  }
  default
}

apply_mhe_restr <- function(p, restr = FALSE, overrides = list()) {
  if (!isTRUE(restr)) return(p)
  vals <- restr_params_central
  if (length(overrides)) vals <- modifyList(vals, overrides)
  p$PRICEREDUCTION <- vals$PRICEREDUCTION
  p$COSTDAY        <- vals$COSTDAY
  p$D_BLOCKMEAN    <- vals$D_BLOCKMEAN
  p$PRICEPCR       <- vals$PRICEPCR
  p$PROPPCR        <- vals$PROPPCR
  p
}


#--------------------RUNNER

# runner 03 : TR_eff_ref imposé au scénario MHE et CULL recalculé en conséquence
run_scenario <- function(p, TR_eff_ref, mhe = FALSE){
  # Fréquence de vêlage → veaux sevrés/an
  IVV_years <- p$IVV / 365
  n_weaned  <- (1 / IVV_years) * (1 - p$MO_WEAN)

  # TR_eff utilisé quelque soit le scénario
  TR_eff_used <- TR_eff_ref

  # CULL utilisé pour REV_COW :
  # - en référence : CULL tel quel
  # - en MHE : CULL = TR_eff_ref - MO_COW_mhe (tronqué à 0)
  CULL_used <- if (isTRUE(mhe)) {
    val <- TR_eff_ref - p$MO_COW
    if (val < 0) warning("CULL_used < 0 (MO_COW_mhe > TR_eff_ref) : tronqué à 0.")
    pmax(val, 0)
  } else {
    p$CULL
  }

  # 1) Décomposition par sexe AVANT renouvellement
  split      <- split_weaned(n_weaned, p$PR_MA)
  # 2) Ventes broutards par sexe (TR_eff s’applique aux femelles)
  sold       <- sold_by_sex(split$n_weaned_m, split$n_weaned_f, TR_eff_used)
  n_WEAN_sold <- sold$n_WEAN_sold_m + sold$n_WEAN_sold_f

  # --------  runner partie conversion coûts par UGB -> par vache --------
  # Attendus dans p : ugb_by_cow, cout_alim_ugb, cout_elevage_ugb
  if (is.null(p$ugb_by_cow) || is.null(p$cout_alim_ugb) || is.null(p$cout_elevage_ugb)) {
    stop("Paramètres manquants : 'ugb_by_cow', 'cout_alim_ugb' et/ou 'cout_elevage_ugb'.")
  }
  cout_alim     <- p$cout_alim_ugb    * p$ugb_by_cow
  cout_elevage  <- p$cout_elevage_ugb * p$ugb_by_cow

  # --------------suite du runner : calcul économique-------------------------
  # Revenus
  REV_COW_val <- REV_COW(CULL_used, p$PRICE_CULL)
  REVY       <- REV_WEAN(sold$n_WEAN_sold_m, sold$n_WEAN_sold_f, p$PRICE_WEANM, p$PRICE_WEANF)
  REV_WEAN_val  <- REVY$total

  # Coûts
  COST_PROD_val  <- COST_PROD(cout_alim, cout_elevage)
  pricereduction <- p_num(p, c("PRICEREDUCTION", "DPRICE_ABS"))
  costday        <- p_num(p, "COSTDAY")
  d_blockmean    <- p_num(p, "D_BLOCKMEAN")
  proppcr        <- p_num(p, c("PROPPCR", "SH_PCR"))
  pricepcr       <- p_num(p, c("PRICEPCR", "C_PCR"))
  COST_PRIX_val  <- COST_PRIX(n_WEAN_sold, pricereduction)
  COST_BLOC_val  <- COST_BLOC(n_WEAN_sold, costday, d_blockmean)
  COST_PCR_val   <- COST_PCR(n_WEAN_sold, proppcr, pricepcr)
  COST_RESTR_val <- COST_PRIX_val + COST_BLOC_val + COST_PCR_val
  #marge brute
  MB_op <- (REV_COW_val + REV_WEAN_val) - (COST_PROD_val + p$COST_VET_D + COST_RESTR_val)

  list(
    MB_op = MB_op,
    breakdown = list(
      # Entrées & dérivées
      CULL_input = p$CULL,            # valeur entrée (utile pour traçabilité)
      CULL_used  = CULL_used,         # valeur effectivement utilisée pour REV_COW
      MO_COW = p$MO_COW, MO_WEAN = p$MO_WEAN,
      TR_eff_ref = TR_eff_ref,          # constant (référence)
      IVV = p$IVV, n_weaned = n_weaned,
      n_weaned_m = split$n_weaned_m, n_weaned_f = split$n_weaned_f,
      n_WEAN_sold_m = sold$n_WEAN_sold_m, n_WEAN_sold_f = sold$n_WEAN_sold_f,
      n_WEAN_sold = n_WEAN_sold,
      # Revenus / Coûts
      REV_COW = REV_COW_val, REV_WEAN = REV_WEAN_val,
      REV_WEAN_m = REVY$rev_m, REV_WEAN_f = REVY$rev_f,
      # Trace coûts UGB -> vache
      ugb_by_cow       = p$ugb_by_cow,
      cout_alim_ugb    = p$cout_alim_ugb,
      cout_elevage_ugb = p$cout_elevage_ugb,
      cout_alim        = cout_alim,
      cout_elevage     = cout_elevage,
      COST_PROD = COST_PROD_val, COST_VET_D = p$COST_VET_D,
      COST_PRIX = COST_PRIX_val, COST_BLOC = COST_BLOC_val, COST_PCR = COST_PCR_val,
      COST_RESTR = COST_RESTR_val,
      PRICEREDUCTION = pricereduction, COSTDAY = costday, D_BLOCKMEAN = d_blockmean,
      PROPPCR = proppcr, PRICEPCR = pricepcr
    )
  )
}


# --- fonction apply Impacts (inchangée) ---
apply_impacts <- function(p, impacts, sequential = TRUE) {
  if (is.null(impacts)) return(p)
  p_eff <- p
  base_val <- function(current, ref) if (sequential) current else ref

  if (!is.null(impacts$dIVV) && !is.null(p$IVV))
    p_eff$IVV <- base_val(p_eff$IVV, p$IVV) + impacts$dIVV

  if (!is.null(impacts$dMO_WEAN))
    p_eff$MO_WEAN <- base_val(p_eff$MO_WEAN, p$MO_WEAN) + impacts$dMO_WEAN

  ## pas de modification de CULL en v03
  if (!is.null(impacts$dMO_COW))
    p_eff$MO_COW <- base_val(p_eff$MO_COW, p$MO_COW) + impacts$dMO_COW

  # garde-fous
  if (!is.null(p_eff$MO_WEAN))  p_eff$MO_WEAN  <- min(max(p_eff$MO_WEAN, 0), 1)
  if (!is.null(p_eff$CULL))    p_eff$CULL    <- max(p_eff$CULL, 0)
  if (!is.null(p_eff$MO_COW)) p_eff$MO_COW <- max(p_eff$MO_COW, 0)

  p_eff
}


# --- Utilitaires tables ---
to_row <- function(name, ref, mhe) data.frame(item = name, ref = ref, mhe = mhe, delta = mhe - ref)
params_to_df <- function(lst, label){
  data.frame(item = names(lst), ref = unlist(lst), mhe = NA, delta = NA, block = label, stringsAsFactors = FALSE)
}
params_to_df_mhe <- function(lst, label){
  data.frame(item = names(lst), ref = NA, mhe = unlist(lst), delta = NA, block = label, stringsAsFactors = FALSE)
}
