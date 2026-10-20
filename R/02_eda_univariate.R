# Phase 2 : statistique descriptive univariee et bivariee selon les trois axes.

cli::cli_h1("Phase 2 - Analyse exploratoire BAAC")
cli::cli_alert_info("Verification des packages necessaires.")
required_packages <- c(
  "cli", "dplyr", "ggplot2", "here", "purrr", "readr", "scales", "stringr",
  "tibble", "fs"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  cli::cli_alert_warning(
    "Packages manquants : {paste(missing_packages, collapse = ', ')}."
  )
  stop(
    "Packages R manquants : ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}
cli::cli_alert_success("Tous les packages sont disponibles.")

data_path <- here::here("data", "processed", "dataset_analytique_clean.csv")
figure_dirs <- c(
  axe1 = here::here("outputs", "02_eda_univariate", "figures", "axe1_infra"),
  axe2 = here::here("outputs", "02_eda_univariate", "figures", "axe2_usagers"),
  axe3 = here::here("outputs", "02_eda_univariate", "figures", "axe3_temp")
)
table_dirs <- c(
  axe1 = here::here("outputs", "02_eda_univariate", "tables", "axe1_infra"),
  axe2 = here::here("outputs", "02_eda_univariate", "tables", "axe2_usagers"),
  axe3 = here::here("outputs", "02_eda_univariate", "tables", "axe3_temp")
)

cli::cli_h2("Preparation des dossiers de sortie")
cli::cli_alert_info("Creation des dossiers de figures et de tables par axe.")
fs::dir_create(c(unname(figure_dirs), unname(table_dirs)))
cli::cli_alert_success("Les dossiers de sortie sont disponibles.")

if (!file.exists(data_path)) {
  cli::cli_alert_warning("Fichier absent : {data_path}.")
  stop("Base analytique introuvable : ", data_path, call. = FALSE)
}

save_plot <- function(plot, directory, filename, width = 8, height = 5) {
  ggplot2::ggsave(
    filename = file.path(figure_dirs[[directory]], filename),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = 300,
    bg = "white"
  )
}

require_columns <- function(data, columns, context) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0L) {
    cli::cli_alert_warning(
      "{context} : colonnes absentes ({paste(missing_columns, collapse = ', ')})."
    )
    stop(
      "Colonnes absentes pour ", context, " : ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
}

skewness_direct <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 3L || stats::sd(x) == 0) {
    return(NA_real_)
  }
  mean((x - mean(x))^3) / stats::sd(x)^3
}

write_contingency <- function(data, x, y, prefix, table_dir) {
  contingency <- table(data[[x]], data[[y]])
  readr::write_csv2(
    as.data.frame.matrix(contingency, check.names = FALSE) |>
      tibble::rownames_to_column(var = x),
    file.path(table_dir, paste0(prefix, "_effectifs.csv"))
  )
  readr::write_csv2(
    as.data.frame.matrix(prop.table(contingency, 1), check.names = FALSE) |>
      tibble::rownames_to_column(var = x),
    file.path(table_dir, paste0(prefix, "_profils_lignes.csv"))
  )
  readr::write_csv2(
    as.data.frame.matrix(prop.table(contingency, 2), check.names = FALSE) |>
      tibble::rownames_to_column(var = x),
    file.path(table_dir, paste0(prefix, "_profils_colonnes.csv"))
  )
  contingency
}

plot_gravity_proportions <- function(data, grouping, directory, filename, title) {
  plot <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data[[grouping]], fill = grav)
  ) +
    ggplot2::geom_bar(position = "fill") +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      labels = scales::percent
    ) +
    ggplot2::labs(
      title = title,
      x = grouping,
      y = "Proportion (%)",
      fill = "Gravite"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 35, hjust = 1)
    )
  save_plot(plot, directory, filename)
}

cli::cli_h2("Importation et controle de la base analytique")
cli::cli_alert_info("Lecture de dataset_analytique_clean.csv avec read_csv2().")
df <- readr::read_csv2(
  data_path,
  locale = readr::locale(encoding = "UTF-8"),
  show_col_types = FALSE
)
cli::cli_alert_info("Base importee : {nrow(df)} lignes et {ncol(df)} colonnes.")
cli::cli_alert_info("Verification stricte de l'absence de valeurs manquantes.")
stopifnot(sum(is.na(df)) == 0)
cli::cli_alert_success("La base ne contient aucune valeur manquante.")

# --- Axe 1 : infrastructures et typologie des voies ---
cli::cli_h1("Axe 1 - Infrastructures et typologie des voies")
cli::cli_h2("Statistiques descriptives de la VMA selon catr")
cli::cli_alert_info("Calcul de la moyenne, mediane, IQR et skewness.")
require_columns(df, c("vma", "catr"), "Axe 1 - VMA")
axe1_vma <- df |>
  dplyr::group_by(catr) |>
  dplyr::summarise(
    n = dplyr::n(),
    moyenne = mean(vma),
    mediane = stats::median(vma),
    iqr = stats::IQR(vma),
    skewness = skewness_direct(vma),
    .groups = "drop"
  )
readr::write_csv2(
  axe1_vma,
  file.path(table_dirs[["axe1"]], "axe1_statistiques_vma_catr.csv")
)
cli::cli_alert_success("Statistiques VMA exportees.")

cli::cli_h2("Visualisation de la VMA")
cli::cli_alert_info("Export de l'histogramme et du boxplot de la VMA.")
axe1_histogram <- ggplot2::ggplot(df, ggplot2::aes(x = vma)) +
  ggplot2::geom_histogram(
    bins = 30,
    fill = "#2C7FB8",
    colour = "white"
  ) +
  ggplot2::facet_wrap(~ catr, scales = "free_y") +
  ggplot2::labs(
    title = "Distribution de la VMA selon le type de route",
    x = "Vitesse maximale autorisee (km/h)",
    y = "Effectif"
  ) +
  ggplot2::theme_minimal()
save_plot(axe1_histogram, "axe1", "histogramme_vma_catr.png")

axe1_boxplot_vma <- ggplot2::ggplot(
  df,
  ggplot2::aes(x = grav, y = vma)
) +
  ggplot2::geom_boxplot(fill = "#9ECAE1", colour = "#08519C") +
  ggplot2::labs(
    title = "VMA selon la gravite",
    x = "Gravite",
    y = "Vitesse maximale autorisee (km/h)"
  ) +
  ggplot2::theme_minimal()
save_plot(axe1_boxplot_vma, "axe1", "boxplot_vma_grav.png")
cli::cli_alert_success("Visualisations VMA exportees.")

cli::cli_h2("Proportions de gravite selon les infrastructures")
cli::cli_alert_info("Production des barplots en pourcentage pour catr, infra, plan et prof.")
require_columns(df, c("grav", "infra", "plan", "prof"), "Axe 1 - infrastructures")
for (variable in c("catr", "infra", "plan", "prof")) {
  write_contingency(
    df,
    variable,
    "grav",
    paste0("axe1_", variable, "_gravite"),
    unname(table_dirs[["axe1"]])
  )
  plot_gravity_proportions(
    df,
    variable,
    "axe1",
    paste0("barplot_gravite_", variable, ".png"),
    paste("Proportion des niveaux de gravite selon", variable)
  )
}
cli::cli_alert_success("Barplots de l'Axe 1 exportes en proportions.")

# --- Axe 2 : vulnerabilite des usagers et equipements ---
cli::cli_h1("Axe 2 - Vulnerabilite des usagers et equipements")
cli::cli_h2("Age et tranche d'age selon la gravite")
cli::cli_alert_info("Export du boxplot de l'age et du barplot en proportions des tranches d'age.")
require_columns(df, c("age", "tranche_age", "grav"), "Axe 2 - age")
axe2_age <- df |>
  dplyr::group_by(grav, tranche_age) |>
  dplyr::summarise(
    n = dplyr::n(),
    age_moyen = mean(age),
    age_mediane = stats::median(age),
    age_iqr = stats::IQR(age),
    .groups = "drop"
  )
readr::write_csv2(
  axe2_age,
  file.path(table_dirs[["axe2"]], "axe2_age_gravite.csv")
)

axe2_boxplot_age <- ggplot2::ggplot(
  df,
  ggplot2::aes(x = grav, y = age, fill = grav)
) +
  ggplot2::geom_boxplot() +
  ggplot2::labs(
    title = "Distribution de l'age selon la gravite",
    x = "Gravite",
    y = "Age",
    fill = "Gravite"
  ) +
  ggplot2::theme_minimal()
save_plot(axe2_boxplot_age, "axe2", "boxplot_age_grav.png")
plot_gravity_proportions(
  df,
  "tranche_age",
  "axe2",
  "barplot_tranche_age_grav.png",
  "Proportion des niveaux de gravite selon la tranche d'age"
)
cli::cli_alert_success("Analyses age et tranche d'age exportees.")

cli::cli_h2("Liaison entre presence_secu et gravite")
cli::cli_alert_info("Export des contingences, profils et test du Chi-2.")
require_columns(df, "presence_secu", "Axe 2 - equipement")
axe2_contingency <- write_contingency(
  df,
  "presence_secu",
  "grav",
  "axe2_presence_secu_gravite",
  unname(table_dirs[["axe2"]])
)
res_chi2 <- suppressWarnings(stats::chisq.test(axe2_contingency))
cli::cli_alert_info(
  "Chi-2 : statistique = {unname(res_chi2$statistic)}, ",
  "ddl = {unname(res_chi2$parameter)}, ",
  "p-value = {format.pval(res_chi2$p.value)}."
)
cramers_v <- sqrt(
  unname(as.numeric(res_chi2$statistic)) /
    (sum(axe2_contingency) * min(dim(axe2_contingency) - 1L))
)
axe2_tests <- tibble::tibble(
  test = "Chi-2 d'independance",
  chi2 = unname(as.numeric(res_chi2$statistic)),
  ddl = unname(as.integer(res_chi2$parameter)),
  p_value = res_chi2$p.value,
  cramers_v = cramers_v,
  n = sum(axe2_contingency)
)
readr::write_csv2(
  axe2_tests,
  file.path(table_dirs[["axe2"]], "axe2_tests_presence_secu_gravite.csv")
)
plot_gravity_proportions(
  df,
  "presence_secu",
  "axe2",
  "barplot_presence_secu_grav.png",
  "Proportion de gravite selon la presence d'equipement"
)
cli::cli_alert_success("Chi-2, V de Cramer, contingences et profils exportes.")

# --- Axe 3 : temporalite, calendrier et facteurs exogenes ---
cli::cli_h1("Axe 3 - Temporalite et facteurs exogenes")
cli::cli_h2("Gravite selon le calendrier")
cli::cli_alert_info("Recodage des variables binaires et analyse des quatre niveaux de gravite.")
require_columns(
  df,
  c("grav", "jours_feries", "vacances_scolaires", "jour_semaine"),
  "Axe 3 - calendrier"
)
df <- df |>
  dplyr::mutate(
    jours_feries = factor(
      as.character(jours_feries),
      levels = c("0", "1"),
      labels = c("Non", "Oui")
    ),
    vacances_scolaires = factor(
      as.character(vacances_scolaires),
      levels = c("0", "1"),
      labels = c("Non", "Oui")
    )
  )
axe3_calendar <- purrr::map_dfr(
  c("jours_feries", "vacances_scolaires", "jour_semaine"),
  function(variable) {
    df |>
      dplyr::group_by(modalite = .data[[variable]], grav) |>
      dplyr::summarise(
        accidents = dplyr::n(),
        .groups = "drop"
      ) |>
      dplyr::group_by(modalite) |>
      dplyr::mutate(
        proportion = accidents / sum(accidents),
        variable = variable,
        .before = 1
      ) |>
      dplyr::ungroup()
  }
)
readr::write_csv2(
  axe3_calendar,
  file.path(table_dirs[["axe3"]], "axe3_taux_gravite_calendrier.csv")
)
for (variable in c("jours_feries", "vacances_scolaires", "jour_semaine")) {
  axe3_calendar_plot <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = .data[[variable]], fill = grav)
  ) +
    ggplot2::geom_bar(position = "fill") +
    ggplot2::scale_y_continuous(
      limits = c(0, 1),
      labels = scales::percent_format()
    ) +
    ggplot2::labs(
      title = paste("Proportion des niveaux de gravite selon", variable),
      x = variable,
      y = "Proportion (%)",
      fill = "Gravite"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
  save_plot(
    axe3_calendar_plot,
    "axe3",
    paste0("barplot_", variable, "_gravite.png")
  )
}
cli::cli_alert_success("Barplots calendaires en pourcentage exportes.")

cli::cli_h2("Distribution horaire et severite par tranche horaire")
cli::cli_alert_info("Analyse de la distribution horaire via heure_exacte...")
require_columns(df, c("heure_exacte", "tranche_horaire"), "Axe 3 - horaire")
hour_data <- df |>
  dplyr::mutate(
    heure_analyse = as.integer(
      stringr::str_extract(as.character(heure_exacte), "^[0-9]{1,2}")
    )
  ) |>
  dplyr::filter(dplyr::between(heure_analyse, 0L, 23L))
axe3_hour <- hour_data |>
  dplyr::count(heure_analyse, name = "accidents") |>
  dplyr::arrange(heure_analyse)
readr::write_csv2(
  axe3_hour,
  file.path(table_dirs[["axe3"]], "axe3_distribution_horaire.csv")
)
axe3_hour_plot <- ggplot2::ggplot(
  axe3_hour,
  ggplot2::aes(x = heure_analyse, y = accidents)
) +
  ggplot2::geom_col(fill = "#3182BD") +
  ggplot2::scale_x_continuous(breaks = 0:23) +
  ggplot2::labs(
    title = "Distribution horaire des accidents",
    x = "Heure",
    y = "Nombre d'accidents"
  ) +
  ggplot2::theme_minimal()
save_plot(axe3_hour_plot, "axe3", "distribution_horaire.png")

axe3_tranche_horaire <- df |>
  dplyr::group_by(tranche_horaire) |>
  dplyr::summarise(
    accidents = dplyr::n(),
    .groups = "drop"
  )
readr::write_csv2(
  axe3_tranche_horaire,
  file.path(table_dirs[["axe3"]], "axe3_taux_gravite_tranche_horaire.csv")
)
axe3_tranche_plot <- ggplot2::ggplot(
  df,
  ggplot2::aes(x = tranche_horaire, fill = grav)
) +
  ggplot2::geom_bar(position = "fill") +
  ggplot2::scale_y_continuous(
    limits = c(0, 1),
    labels = scales::percent_format()
  ) +
  ggplot2::labs(
    title = "Proportion de severite par tranche horaire",
    x = "Tranche horaire",
    y = "Proportion (%)",
    fill = "Gravite"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
save_plot(axe3_tranche_plot, "axe3", "barplot_severite_tranche_horaire.png")
cli::cli_alert_success("Distribution horaire et taux par tranche horaire exportes.")

cli::cli_h1("Phase 2 terminee")
cli::cli_alert_success("Tous les tableaux et graphiques ont ete sauvegardes.")
