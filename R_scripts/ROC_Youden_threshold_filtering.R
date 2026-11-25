# Script can be used to filter classification results to Youden index saltmarsh 
# probability threshold calculated using validation dataset such as digitised 
# "true positive" and "true negative" saltmarsh areas from ground truthing or 
# UAV imagery

rm(list = ls()) # Clear global environment

library(dplyr)
library(tidyverse)
library(terra)
library(RColorBrewer)
library(sp)
library(here)

setwd(here())

# Classification results - update file path as needed
classified <- 
  rast("R_pred/Cross_testing/Cobmarsh/Cob_rf_pred_prob_2020Tr_2024Te_750_7.tif")

# Read in accuracy assessment polygons - update file path as needed
Acc_Folder <- "D:/Ground Truthing/Acc_assess/Cobmarsh"
setwd(Acc_Folder)

# True positive saltmarsh areas
SM_poly <- read_sf(dsn = Acc_Folder, layer = "Cobmarsh_2024_digitised_SM")
# True negative saltmarsh areas
non_SM_poly <- read_sf(dsn = Acc_Folder, layer = "Cobmarsh_2024_non_SM")

# Extract predictions for the true positive and true negative areas
Saltmarsh <- raster::extract(x = classified, 
                                 y = SM_poly, 
                                 df = TRUE)

Non_SM <- raster::extract(x = classified, 
                              y = non_SM_poly, 
                              df = TRUE)

TrueSM_pred <- as.data.frame(Saltmarsh, xy = FALSE)
NonSM_pred <- as.data.frame(Non_SM, xy = FALSE)

TrueSM_pred$truth <- 1
NonSM_pred$truth <- 0

data <- rbind(TrueSM_pred, NonSM_pred)

# Compute the ROC curve using pROC::roc()
roc_obj <- roc(response = data$truth, predictor = data$Saltmarsh)

# View summary details (including AUC)
print(roc_obj)

# Calculate the Area Under the Curve (AUC)
auc_val <- round(auc(roc_obj),2)
print(auc_val)

# Find the optimal threshold based on the Youden Index
optimal_coords <- coords(roc_obj, x = "best", best.method = "youden")
Threshold <- round(optimal_coords$threshold, 3)
ThresStr <- deparse(Threshold)
Thres <- sub("\\.", "_", ThresStr)

polun <- as.polygons(classified, aggregate=TRUE)
#plot(polun, col="yellow") # Uncomment to plot polygons

# Export an "unfiltered" shapefile from the classification results
setwd(here())
FNUN <- "Unfiltered/Cob/Cross_2024_20Tr_pols.shp" # Update file path as needed
writeVector(polun, FNUN)

# Filter classified raster to remove low probability saltmarsh
classified[classified["Saltmarsh"] < Threshold ] = NA 

pol <- as.polygons(classified, aggregate=TRUE)
#plot(pol, col="green") # Uncomment to plot filtered polygons

# Export filtered shapefile and raster. Update file paths as needed.
setwd(here())
FN <- 
  paste("Filtered/Cob/Cross_2024_20Tr_filtered_saltmarsh_",Thres,".tif", sep="")
FNS <- 
  paste("Filtered/Cob/Shapefiles/Cross_2024_20Tr_filtered_saltmarsh_",
        Thres,".shp", sep="")
writeRaster(classified, filename = FN)
writeVector(pol, FNS)
