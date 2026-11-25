# Script can be used to filter classification results to minimum saltmarsh 
# predicted probability in "true positive" predictions of testing data. 

rm(list = ls()) # Clear global environment

library(dplyr)
library(tidyverse)
library(terra)
library(RColorBrewer)
library(sp)
library(here)

# Read predicted probabilities dataset exported during classification training
# Update file paths as needed
setwd(here())
# Predicted probabilities CSV file:
df <- read_csv('Pred_probs/CSVs/Orplands/2008_pred_probs_LD.csv')
# Classification output raster: 
classified <- rast("R_pred/Orplands/rf_pred_prob_2008_LD_750_7_R.tif")
# File path to be used later in script for exporting unfiltered shapefile:
FNUN <- "Unfiltered/Orp/2008_LD_pols.shp" 

# Record true positives as 1 and incorrect as o
df$TruePos <- ifelse(df$PredictedClass == df$GroundTruth, 1, 0)

sm_pred_TP <- subset(df, PredictedClass == "Saltmarsh" & TruePos==1)
minTP <- round(min(sm_pred_TP$Saltmarsh),3)
TPStr <- deparse(minTP)
MinTPS <- sub("\\.", "_", TPStr)
# File path to be used for exporting filtered shapefile:
FNS <- paste("Filtered/Orp/Shapefiles/2008_LD_filtered_saltmarsh_",
             MinTPS,".shp", sep="")
polun <- as.polygons(classified, aggregate=TRUE)
#plot(polun, col="yellow") # Uncomment to plot unfiltered polygons

writeVector(polun, FNUN) # Export unfiltered shapefile

# Filter classified raster to remove low probability saltmarsh
classified[classified["Saltmarsh"] < minTP ] = NA 

# Convert filtered polygons to shapefile and export
pol <- as.polygons(classified, aggregate=TRUE)
plot(pol, col="green") # Plot filtered polygons
writeVector(pol, FNS)

