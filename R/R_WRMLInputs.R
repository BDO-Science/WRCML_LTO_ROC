# This script converts the CalSim3 data output into an input file for the WRML models

library(dplyr)
library(stringr)
library(tidyr)
library(purrr)
library(pbapply)

# Order of operations -----------------------------------------------------

# 1)
# Read in our training dataset, which ranges from 2004-10-25 to 2020-06-22. 
# The first date is based on lagged rbdd passage estimate; the last date is based on the last date of salvage
# 2)
# Define the spatTempAgg functions used to assign the spatial and temporal aggregations and lags for feature creation
# 3)
# Restructure the data to be ingested by the spatTempAgg function
# 4)
# Create features via the spatTempAgg function

data <- list()
# Step 1: reading in training dataset -------------------------------------
# Can I place this rds somewhere on this project's directory?
# This file will be required to pull the other features required to run the model (altering only flows in these alternatives)
data$wrmlTrainingData <- readRDS(file.path("Hydro model output", "joinedDF.rds"))

data$alternatives <- read.csv(file.path("Hydro model output", "Dailydata_converted_from_Calsim3_NAA.csv")) %>% 
  mutate(Date = as.Date(Date))
# str(data) looks fine

# Step 2: Sourcing spatio-temporal aggregation function -------------------

source(file.path("R", "R_spatTempAgg.R"))

# Step 3: restructure input data ------------------------------------------
# There are 11 features in our model, of which 6 are being manipulated in this alternative analysis. For the remaining
# 5 features, we will grab from the training dataset

# IMPORTANT: due to how the spatTempAgg function is written, there should various combinations of the 
# region, subregion, station, variable, and value columns per feature for the naming functionality to work
# The specific combinations are a bit tricky and you must refer to the training data to see what's populated

data$joinedNew <- list(
  # secchi at sherwood harbor (sacTrawl)
  secchiSherwood = data$wrmlTrainingData %>% 
    filter(variable == "secchi", station == "sherwoodHarbor"),
  # water temperature from the upper sacramento river subregion
  waterTempUpperSacR = data$wrmlTrainingData %>% 
    filter(variable == "waterTemp", subregion == "Upper Sacramento River"),
  # water temperature from RBDD RST
  waterTempRBDD = data$wrmlTrainingData %>% 
    filter(variable == "waterTemp", station == "RBDD"),
  # passage estimate RBDD
  passEstRBDD = data$wrmlTrainingData %>% 
    filter(variable == "passEst_WR", station == "RBDD"),
  # water temperature from upper sacramento river subregion
  catchUpperSacR = data$wrmlTrainingData %>% 
    filter(variable == "catch_WRWild", subregion == "Upper Sacramento River"),
  # Now for the alternative flow metrics
  # DCC positions, percent opened
  dccPercentOpened = data$alternatives %>% 
    transmute(date = Date,
              variable = "dccPerc",
              value = ifelse(DCC_opened == "Yes", 100, 0),
              station = "DCC"),
  # QEXPORTS
  exports = data$alternatives %>% 
    transmute(date = Date,
              variable = "EXPORTS",
              value = EXPORT, 
              station = "dayflow"),
  # RBDD flow, which is peak BND daily flow
  rbddFlow = data$alternatives %>% 
    transmute(date = Date,
              variable = "flow",
              value = BND_flow,
              region = "Main Stem Sacramento River",
              subregion = "Upper Main Stem Sacramento River",
              station = "RBDD",
              variable = "flow"),
  # QSAC
  sacFlow = data$alternatives %>% 
    transmute(date = Date,
              variable = "SAC",
              value = SAC,
              station = "dayflow"),
  # QSJR
  sjrFlow = data$alternatives %>% 
    transmute(date = Date,
              variable = "SJR",
              value = SJR,
              station = "dayflow"),
  # QYOLO
  yoloFlow = data$alternatives %>% 
    transmute(date = Date,
              variable = "YOLO",
              value = YOLO,
              station = "dayflow")
) %>% 
  bind_rows()

# Step 4: creating features -----------------------------------------------

features <- spatTempAgg_makeDF(file.path("Hydro model output", "spatTempFinalModel.csv"))
