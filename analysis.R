
# Load packages
pacs <- c(
  "tidyverse", 
  "patchwork",
  "tidytext",
  "janitor", 
  "readxl",
  "gt",
  "gtsummary"
)

sapply(pacs, require, character.only = TRUE)

# Read participant demog + biomarker data ---------------------------------

# Read data; n.obs = 231 from 31 distinct partIDs
# Remove variables that are not needed
bm_long <- read_excel("./data/MANCAR_InBody_lab_10132026.xlsx", na = c("", ".")) %>% 
  clean_names() %>% 
  select(-matches("right|left|trunk|arm|leg|cellular|ecw|visceral|impedance|control|score|basal|smi")) %>% 
  rename(
    partid = part_id,
    seq    = gr_rand,
    height = x2_height,
    sex    = x3_gender,
    age    = x4_age,
    date   = x5_test_date_time,
    weight = x6_weight,
    tbw    = x7_tbw_total_body_water,
    dlm    = x10_dlm_dry_lean_mass,
    bfm    = x11_bfm_body_fat_mass,
    lbm    = x12_lbm_lean_body_mass,
    smm    = x13_smm_skeletal_muscle_mass,
    bmi    = x14_bmi_body_mass_index,
    pbf    = x15_pbf_percent_body_fat,
    tnfa   = tnf_alpha,
    il_1b  = il_1_beta,
    hdl    = hdl_cho_l,
    isop   = x8_isoprostanglin_f2a,
    oxldl  = oxidized_ldl
  ) %>% 
  mutate(
    seq        = factor(seq, levels = c("C", "M"), labels = c("Control-Mango", "Mango-Control")),
    sex        = factor(sex),
    date       = as_date(dmy_hms(date)),
    phase      = case_when(
      visit == 0              ~ 0,
      visit >= 1 & visit <= 3 ~ 1,
      visit >= 4 & visit <= 7 ~ 2,
      ),
    phase      = factor(phase),
    trt        = case_when(
      phase == 0 ~ "Baseline",
      phase == 1 & seq == "Control-Mango" ~ "Control",
      phase == 2 & seq == "Control-Mango" ~ "Mango",
      phase == 1 & seq == "Mango-Control" ~ "Mango",
      phase == 2 & seq == "Mango-Control" ~ "Control",
    ),
    trt        = factor(trt),
    isop       = isop       / 1000,        # Convert to ng/mL
    crp        = crp        / 1000,        # Convert to mg/L
    e_selectin = e_selectin / 1000,        # Convert to ng/mL
    icam_1     = icam_1     / 1000,        # Convert to ng/mL
    vcam_1     = vcam_1     / 1000         # Convert to ng/mL
  ) %>% 
  select(partid, status, seq, visit, phase, trt, everything())

bm_long

# Variables
names(bm_long)

# Demographic variables
demog_vars <- c(
  "sex",
  "age",
  "bmi"
)

# Primary outcomes
primary_bm <- c(
  "glucose", 
  "insulin", 
  "homair", 
  "a1c", 
  "chol", 
  "ldl", 
  "hdl", 
  "trig", 
  "oxldl",
  "isop"
)

# Secondary outcomes
secondary_bm <- c(
  "crp", 
  "e_selectin", 
  "icam_1", 
  "vcam_1",
  "pbf", 
  "bfm",
  "lbm"      # Check with Celine
)

# 31 distinct subjects 
n_distinct(bm_long$partid)

# 3 participants dropped out
# MANCAR17, MANCAR24, MANCAR27
bm_long %>% filter(status == "Dropped") %>% 
  select(partid, status, visit)

bm_long %>% 
  group_by(partid) %>% 
  count() %>% 
  print(n = Inf)

# Baseline
baseline <- bm_long %>% filter(visit == 0)

# MANCAR28 visit date
bm_long %>% 
  filter(partid == "MANCAR28") %>% 
  select(partid, seq, visit, trt, date)


# Check distributions -----------------------------------------------------

# Histogram for all primary & secondary outcomes
bm_long %>% 
  filter(visit %in% c(0, 3, 7)) %>% 
  select(partid, all_of(primary_bm), all_of(secondary_bm)) %>% 
  pivot_longer(-partid, names_to = "var", values_to = "value") %>%
  mutate(var = factor(var, levels = c(primary_bm, secondary_bm))) %>% 
  ggplot(aes(x = value)) +
  geom_histogram(bins = 20) +
  facet_wrap(~var, scales = "free", ncol = 6, labeller = as_labeller(outcome_labels)) +
  labs(x = NULL, y = "Count") +
  theme_bw()

# Calculate skewness for all outcomes 
bm_long %>%
  select(all_of(primary_bm), all_of(secondary_bm)) %>% 
  summarise(across(where(is.numeric), \(x) moments::skewness(x, na.rm = TRUE))) %>% 
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Skewness")

# Descriptive tables ------------------------------------------------------

baseline %>% 
  mutate(sex = factor(sex, levels = c("F", "M"), labels = c("Female", "Male"))) %>% 
  select(seq, all_of(demog_vars), all_of(primary_bm), all_of(secondary_bm)) %>% 
  tbl_summary(
    by = seq,
    label = list(
      sex        ~ "Sex",
      age        ~ "Age",
      bmi        ~ "BMI (kg/m²)",
      glucose    ~ "Fasting glucose (mg/dL)",
      insulin    ~ "Fasting insulin (µIU/mL)",
      homair     ~ "HOMA2-IR",
      a1c        ~ "HgbA1c (%)",
      chol       ~ "Total cholesterol (mg/dL)",
      ldl        ~ "LDL-cholesterol (mg/dL)",
      hdl        ~ "HDL-cholesterol (mg/dL)",
      trig       ~ "Triglycerides (mg/dL)",
      oxldl      ~ "Oxidized LDL-C (ng/mL)",
      isop       ~ "8-iso-PGF2α (ng/mL)",
      crp        ~ "C-reactive protein (mg/L)",
      e_selectin ~ "E-selectin (ng/mL)",
      icam_1     ~ "ICAM-1 (ng/mL)",
      vcam_1     ~ "VCAM-1 (ng/mL)",
      pbf        ~ "Percent body fat (%)",
      bfm        ~ "Body fat mass (kg)",
      lbm        ~ "Lean body mass (kg)"
    ),
    statistic = list(
      all_continuous() ~ "{mean} ({sd})",
      c(crp, insulin, homair, isop) ~ "{median} ({p25}, {p75})"
    ),
    digits    = list(
      all_continuous() ~ c(1, 1),
      c(homair, a1c, isop, crp) ~ c(2, 2)
    ),
    missing   = "no"
  ) %>% 
  modify_spanning_header(all_stat_cols() ~ "**Treatment sequence**") %>% 
  add_overall() %>% 
  bold_labels() %>% 
  as_gt() %>% 
  tab_footnote(
    footnote  = "ICAM-1 missing for 1 participant (above assay range); n = 30 (15 per sequence).",
    locations = gt::cells_body(columns = label, rows = label == "ICAM-1 (ng/mL)")
  )


# Exploratory analysis ----------------------------------------------------

# Plot visit number against visit date
bm_long %>% 
  ggplot(aes(x = date, y = visit, group = partid, color = seq)) +
  geom_point() +
  geom_line() +
  scale_x_date(date_breaks = "2 months", date_labels = "%Y-%m") +
  scale_y_continuous(breaks = 1:7) +
  labs(x = "Date", y = "Visit number", color = "Treatment sequence") +
  theme_bw() +
  theme(legend.position = "bottom")

# Profile plots
# Outcome labels
outcome_labels <- c(
  glucose    = "Glucose (mg/dL)",
  insulin    = "Insulin (µIU/mL)",
  homair     = "HOMA2-IR",
  a1c        = "HbA1c (%)",
  chol       = "Total chol (mg/dL)",
  ldl        = "LDL-C (mg/dL)",
  hdl        = "HDL-C (mg/dL)",
  trig       = "TG (mg/dL)",
  oxldl      = "Ox-LDL (ng/mL)",
  isop       = "8-iso-PGF2α (ng/mL)",
  crp        = "CRP (mg/L)",
  e_selectin = "E-selectin (ng/mL)",
  icam_1     = "ICAM-1 (ng/mL)",
  vcam_1     = "VCAM-1 (ng/mL)",
  pbf        = "Body fat (%)",
  bfm        = "Fat mass (kg)",
  lbm        = "Lean mass (kg)"
)

plot_profile <- function(data, var, ylab = outcome_labels[[var]], log = FALSE) {
  p <- data %>%
    filter(visit %in% c(0, 3, 7), !is.na(.data[[var]])) %>%
    ggplot(aes(x = visit, y = .data[[var]], group = partid, color = seq)) +
    geom_point() +
    geom_line() +
    facet_wrap(~ seq) +
    scale_x_continuous(breaks = c(0, 3, 7), minor_breaks = 0:7) +
    labs(x = "Visit", y = if (log) paste(ylab, "(log scale)") else ylab, title = outcome_labels[[var]]) +
    theme_bw() +
    theme(legend.position = "none")
  
  if (log) p <- p + scale_y_log10() + guides(y = guide_axis_logticks())
  p
}

# Profile plots for glycemic indicators
(plot_profile(bm_long, "glucose") + plot_profile(bm_long, "insulin", log = TRUE)) /
(plot_profile(bm_long, "homair", log = TRUE) + plot_profile(bm_long, "a1c"))

bm_long %>% 
  filter(partid == "MANCAR24") %>% 
  # filter(partid == "MANCAR27") %>% 
  # filter(partid == "MANCAR21") %>% 
  # filter(partid == "MANCAR16") %>% 
  select(partid, visit, trt, glucose, insulin, homair, a1c)

# Profile plots for lipids
(plot_profile(bm_long, "chol") + plot_profile(bm_long, "ldl")) /
(plot_profile(bm_long, "hdl") + plot_profile(bm_long, "trig"))

plot_profile(bm_long, "oxldl")
plot_profile(bm_long, "isop", log = TRUE)
plot_profile(bm_long, "crp", log = TRUE)
plot_profile(bm_long, "e_selectin")
plot_profile(bm_long, "icam_1")
plot_profile(bm_long, "vcam_1")
plot_profile(bm_long, "pbf")
plot_profile(bm_long, "bfm")
plot_profile(bm_long, "lbm")

# plotly version of the profile plot
library(plotly)
plot_profile <- function(data, var, ylab = outcome_labels[[var]], log = FALSE) {
  d <- data %>%
    filter(visit %in% c(0, 3, 7), !is.na(.data[[var]])) %>%
    arrange(partid, visit) %>%
    group_by(partid) %>%
    mutate(hover = paste0("<b>", partid, "</b> (", seq, ")<br>",
                          paste0("Visit ", visit, ": ", signif(.data[[var]], 4),
                                 collapse = "<br>"))) %>%
    ungroup() %>%
    highlight_key(~ partid)
  
  p <- ggplot(d, aes(x = visit, y = .data[[var]], group = partid,
                     color = seq, text = hover)) +
    geom_line() +
    geom_point() +
    facet_wrap(~ seq) +
    scale_x_continuous(breaks = c(0, 3, 7), minor_breaks = 0:7) +
    labs(x = "Visit", y = if (log) paste(ylab, "(log scale)") else ylab,
         title = outcome_labels[[var]]) +
    theme_bw() +
    theme(legend.position = "none")
  
  if (log) p <- p + scale_y_log10()
  
  ggplotly(p, tooltip = "text") %>%
    highlight(on = "plotly_hover", off = "plotly_doubleclick", opacityDim = 0.15)
}

plot_profile(bm_long, "glucose")
plot_profile(bm_long, "insulin", log = TRUE)
plot_profile(bm_long, "homair", log = TRUE)
plot_profile(bm_long, "a1c")
plot_profile(bm_long, "chol")
plot_profile(bm_long, "ldl")
plot_profile(bm_long, "hdl")
plot_profile(bm_long, "trig")
plot_profile(bm_long, "oxldl")
plot_profile(bm_long, "isop", log = TRUE)
plot_profile(bm_long, "crp", log = TRUE)
plot_profile(bm_long, "e_selectin")
plot_profile(bm_long, "icam_1")
plot_profile(bm_long, "vcam_1")
plot_profile(bm_long, "pbf")
plot_profile(bm_long, "bfm")
plot_profile(bm_long, "lbm")

# Waterfall plot
log_vars <- c("insulin", "homair", "trig", "isop", "crp")   # same as the log-scale models

plot_dat <- bm_long %>%
  filter(visit %in% c(3, 7)) %>%
  select(partid, seq, trt, all_of(c(primary_bm, secondary_bm))) %>%
  pivot_longer(-c(partid, seq, trt), names_to = "outcome", values_to = "value") %>%
  pivot_wider(id_cols = c(partid, seq, outcome), names_from = trt, values_from = value) %>%
  mutate(diff = if_else(outcome %in% log_vars, log(Mango / Control), Mango - Control),
         partid  = parse_number(partid),
         outcome = factor(outcome, levels = names(outcome_labels))) %>%
  filter(!is.na(diff)) %>%
  mutate(bar = fct_reorder(paste(outcome, partid), diff))

wf_labels <- outcome_labels
wf_labels[log_vars] <- paste0(outcome_labels[log_vars], "\nlog ratio")

p_waterfall <- ggplot(plot_dat, aes(x = bar, y = diff, fill = seq)) +
  geom_col() +
  geom_hline(yintercept = 0, linewidth = 0.3) +
  facet_wrap(~ outcome, scales = "free", ncol = 6,
             labeller = as_labeller(wf_labels)) +
  scale_x_discrete(labels = \(x) sub(".* ", "", x)) +
  labs(x = "Participant ID", y = "Mango − Control (difference or log ratio)", fill = "Sequence") +
  theme_bw() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))

p_waterfall
