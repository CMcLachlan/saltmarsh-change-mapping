# Script can be used to create an "all data" and a "Landsat-DTM" raster file 
# for use in saltmarsh classifications. 

rm(list = ls()) # clear global environment

# Load packages
library(raster)
library(terra)
library(sf)

# READ ALL DATASETS -----------------------------------------------------------
# Update path and filename as needed to read in study area shapefile
Study_area_folder <- 'D:/EA Data/Jim sites/Cobmarsh/Study_area'
study_area_BNG <- read_sf(dsn = Study_area_folder, layer = "Cobmarsh_study_area")

# Read Landsat data from GEE. Update path to folder containing GEE outputs.
Landsat_Folder <- "D:/Landsat/2023" 
setwd(Landsat_Folder)

# Update file names as needed
Winter <- rast('P75stackLS_Dec_Feb_2022_23.tif')
Spring <- rast('P75stackLS_Mar_May_2022_23.tif')
Summer <- rast('P75stackLS_Jun_Aug_2022_23.tif')
Autumn <- rast('P75stackLS_Sep_Nov_2022_23.tif')

# Load clipped aerial imagery and texture layers. 
# Update path to folder containing aerial imagery.
Aerial_Folder <- "D:/EA Data/Jim sites/Cobmarsh/2023/Aerial"
setwd(Aerial_Folder)

# Update file name as needed.
Aerial_unclip <- rast('Cob_RGBN_2023.tif')
raster::crs(Aerial_unclip) <- crs(study_area_BNG)

# Update file names and paths as needed - texture "SV" and "SA" used here. 
SV_unclip <- rast('Texture/outpute8332a3c45b8450190ea516c48dc49c8_SV.tif')
raster::crs(SV_unclip) <- crs(study_area_BNG)
SA_unclip <- rast('Texture/outpute8332a3c45b8450190ea516c48dc49c8_SA.tif')
raster::crs(SA_unclip) <- crs(study_area_BNG)


# Clip aerial imagery to study area
#setwd(Aerial_Folder)
setwd(Aerial_Folder)
Aerial <- crop(Aerial_unclip, study_area_BNG, mask = TRUE)
# writeRaster(Aerial, filename = "Cob_RGBN_study_area_2023_R.tif")
# Uncomment line above to save separate file containing clipped aerial imagery

# Clip texture layers to study area
SV_unres <- crop(SV_unclip, study_area_BNG, mask = TRUE)
SA_unres <- crop(SA_unclip, study_area_BNG, mask = TRUE)

# Resample texture values to aerial layer
SV <- resample(SV_unres, Aerial, method="bilinear")
SA <- resample(SA_unres, Aerial, method="bilinear")

# Read in digital elevation model - update path and filename as needed
Elevation_Folder <- "D:/EA Data/Jim sites/Cobmarsh/2023/DTM"
setwd(Elevation_Folder)
DTM_unclipped <- rast('Cob_DTM_2023.tif')

# Clip elevation model to study area
DTM <- crop(DTM_unclipped, study_area_BNG, mask = TRUE)
#writeRaster(DTM, filename = "Cobmarsh_DTM_study_area_2023.tif")
# Uncomment line above to save separate file containing clipped elevation model

# PREPARE LANDSAT DATA --------------------------------------------------------
# Extract selected bands from each seasonal dataset from GEE
Aut_NDVI <- Autumn[[1]]
Spr_IBI <- Spring[[7]]
Spr_EVI <- Spring[[9]]
Sum_IBI <- Summer[[7]]
Sum_mSAVI <- Summer[[6]]
Sum_NDVI <- Summer[[1]]
Win_NDVI <- Winter[[1]]
Win_mSAVI <- Winter[[6]]
Win_SRVI <- Winter[[11]]
Win_SRWI <- Winter[[12]]

LS_stack <- c(Aut_NDVI,Spr_IBI,Spr_EVI,Sum_IBI,Sum_mSAVI,Sum_NDVI,Win_NDVI,
              Win_mSAVI,Win_SRVI,Win_SRWI)

names(LS_stack) <- c('Aut_NDVI', 'Spr_IBI', 'Spr_EVI', 'Sum_IBI', 'Sum_mSAVI', 
                     'Sum_NDVI', 'Win_NDVI', 'Win_mSAVI', 'Win_SRVI', 
                     'Win_SRWI')

# Clip to study area and project to CRS of aerial imagery. 
# Update folder/file names as needed. 
Study_area_folder <- 'D:/EA Data/Jim sites/Cobmarsh/Study_area'

# Read in study area in WGS84
study_area <- read_sf(dsn = Study_area_folder, 
                      layer = "Cobmarsh_study_area_WGS84")

LS_stack_study_area <- crop(LS_stack, study_area, mask = TRUE)
plotRGB(LS_stack_study_area, 
        r="Aut_NDVI", 
        g="Sum_IBI", 
        b="Win_SRWI", 
        stretch="hist")

LS_stack_study_area <- project(LS_stack_study_area, crs(Aerial))


# PREPARE LS-DTM stack --------------------------------------------------------
# Resample LS_stack to DTM resolution using bilinear interpolation
LS_1m <- resample(LS_stack_study_area, DTM, method="bilinear")
LS_DTM <- c(DTM,LS_1m)
names(LS_DTM) <- c('DTM', 'Aut_NDVI', 'Spr_IBI', 'Spr_EVI', 'Sum_IBI', 
                   'Sum_mSAVI', 'Sum_NDVI', 'Win_NDVI', 'Win_mSAVI', 'Win_SRVI',
                   'Win_SRWI')
plotRGB(LS_DTM, r="DTM", g="Sum_IBI", b="Spr_IBI", stretch="hist")

# PREPARE All stack -----------------------------------------------------------
# Calculate aerial NDVI (or MGRVI for 2008) 
# Extract the aerial bands - update quoted band names as needed
B <- Aerial[["Cob_RGBN_2023_3"]]
G <- Aerial[["Cob_RGBN_2023_2"]]
R <- Aerial[["Cob_RGBN_2023_1"]]
NIR <- Aerial[["Cob_RGBN_2023_4"]]
Aerial_bands <- c(R,G,B,NIR)

# Calculate MRGVI - uncomment bottom 2 lines, if using. 
# Alternative to NDVI if no NIR band is available.
# Modified Green Red Vegetation Index
#MGRVI <- (G^2 - R^2) / (G^2 + R^2)
#plot(MGRVI, range=c(-1,1))

# Calcualte NDVI
NDVI <- (NIR - R) / (NIR + R)
plot(NDVI, range=c(-1,1))


# Resample DTM and Landsat to aerial resolution for stacking
DTM_resample <- resample(DTM, Aerial, method="bilinear")
LS_study_area_resample <- resample(LS_stack_study_area, Aerial, 
                                   method="bilinear")

# Stack all prepared data 
# Adjust band list and names if no NIR band and/or MGRVI used
Full_stack_named <- c(Aerial_bands, NDVI, DTM_resample, SA, SV,
                           LS_study_area_resample)
names(Full_stack_named) <- c("R", "G", "B", "NIR", "Aer_NDVI", "DTM", "T_SA", 
                                  "T_SV", 'Aut_NDVI', 'Spr_IBI', 
                                  'Spr_EVI', 'Sum_IBI', 'Sum_mSAVI', 'Sum_NDVI',
                                  'Win_NDVI', 'Win_mSAVI', 'Win_SRVI', 
                             'Win_SRWI')
names(Full_stack_named)

# Write both stacks to file - update file path/names as needed. 
Composites_folder <- "D:/EA Data/Jim sites/Cobmarsh/2023/Composites"
setwd(Composites_folder)

writeRaster(Full_stack_named, filename = "Full_stack_Cob_2023_named.tif")
writeRaster(LS_DTM, filename = "LS_DTM_Cob_2023_named.tif")
