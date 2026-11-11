# Sensibilité déterministe one-way sur COST_RESTR (pas de distributions).
# Les tirages MC sont ceux de mc_decomp (même seed / mêmes n_WEAN_sold).

restr_sa_grid <- data.frame(
  scenario = c(
    "No average price effect",
    "Main analysis",
    "High price effect",
    "PCR proportion - low",
    "PCR proportion - high"
  ),
  PRICEREDUCTION = c(0, 60, 100, 60, 60),
  PROPPCR        = c(0.71, 0.71, 0.71, 0.40, 0.80),
  stringsAsFactors = FALSE
)

summarise_restr_sa <- function(mc_decomp, grid = restr_sa_grid,
                               costday = 1, d_blockmean = 5.4, pricepcr = 15) {
  mhe <- mc_decomp[mc_decomp$scen == "MHE", ]
  ref <- mc_decomp[mc_decomp$scen == "REF", ]
  mhe <- mhe[order(mhe$draw), ]
  ref <- ref[order(ref$draw), ]
  stopifnot(nrow(mhe) == nrow(ref), all(mhe$draw == ref$draw))

  n <- if ("n_WEAN_sold" %in% names(mhe)) {
    mhe$n_WEAN_sold
  } else {
    den <- costday * d_blockmean
    ifelse(den == 0, 0, mhe$COST_BLOC / den)
  }

  # Marge EHD hors poste restrictions (démographie + traitements inchangés)
  mb_mhe_core <- mhe$MB_op + mhe$COST_RESTR
  mb_ref <- ref$MB_op

  rows <- lapply(seq_len(nrow(grid)), function(i) {
    pr <- grid$PRICEREDUCTION[i]
    pp <- grid$PROPPCR[i]
    cost_prix  <- n * pr
    cost_bloc  <- n * costday * d_blockmean
    cost_pcr   <- n * pp * pricepcr
    cost_restr <- cost_prix + cost_bloc + cost_pcr
    dmb <- (mb_mhe_core - cost_restr) - mb_ref
    loss <- -dmb
    data.frame(
      scenario       = grid$scenario[i],
      PRICEREDUCTION = pr,
      PROPPCR        = pp,
      COSTPRICE      = mean(cost_prix),
      COSTBLOCK      = mean(cost_bloc),
      COSTPCR        = mean(cost_pcr),
      COSTRESTR      = mean(cost_restr),
      loss_EHD       = mean(loss),
      stringsAsFactors = FALSE
    )
  })
  tab <- do.call(rbind, rows)
  i_main <- match("Main analysis", tab$scenario)
  tab$d_COSTRESTR <- tab$COSTRESTR - tab$COSTRESTR[i_main]
  tab$d_loss      <- tab$loss_EHD - tab$loss_EHD[i_main]
  tab[, c("scenario", "PRICEREDUCTION", "PROPPCR",
          "COSTPRICE", "COSTBLOCK", "COSTPCR", "COSTRESTR", "d_COSTRESTR",
          "loss_EHD", "d_loss")]
}
