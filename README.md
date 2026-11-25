# Saltmarsh change mapping
Classification of saltmarsh extent from Landsat, aerial imagery and digital elevation. 

## How to use
### 1. Required input data
- Study area polygon
- Aerial imagery
- Digital elevation model

### 2. Preparation of data
- Calculate and export Landsat seasonal vegetation indices in Google Earth Engine.
- (If including), calculate gray-level co-occurence matrix texture features (e.g. in QGIS 'r.texture' or in R.)
- Run "Data preparation" script to clip all input data to the study area, resample Landsat and elevation data to aerial
imagery pixel size, and stack all input layers to "all data" and "Landsat-DTM" rasters.
- Digitise training sample locations in a GIS and extract training/testing sample data (e.g. by sampling values from the
digitised locations in a GIS, or using R/other means.) A CSV file is required containing named sample values, each with 
a landcover assigned and "polygon number" to be used for splitting sample values. 

### 3. Run the classification
- Once all data is prepared (raster "stack" of input data and training/testing samples), update the file paths as 
required within the classification script and run the classification using the 
"RF_classification_adapted_from_Joe_Agate" script. 
- Sample data can be adapted to different years of input data to classify multiple dates for the same site in a 
standardised way. 

### 4. Filtering pixels using saltmarsh predicted probability
- Receiver operating characteristic curve with Youden index, or true positive predicted saltmarsh probability in output 
"predprob" CSV files can be used to select a classification threshold at which pixels are included as "saltmarsh", 
rather than taking the original predicted value. 
- To use the ROC curve and Youden index, use "ROC_Youden_threshold_filtering" script
- To use predicted probabilities in testing data, use "Saltmarsh_filtering_on_sample_TP" script.

### 5. Essential validation
- In addition to examining accuracy assessment values, additional data must be used to validate results. Unmanned aerial
vehicle (UAV) imagery from the same year as the classification can be used to inspect locations of saltmarsh, and/or 
ground-truthing data must be used to identify false positive and false negative classified saltmarsh. 

### 6. Interpretation
- After validation and identifying true-positive classified saltmarsh, a quick interpretation of changes may include 
stacking classification results in chronological order to easily visualise trends over time (e.g. earlier years will 
extend beyond later years if there has been erosion, and later years will extend beyond earlier years if there has been 
accretion. Stepwise changes between multiple dates may be visible if changes have been occurring gradually over time.)
- Changes may also be directly identified between dates by subtracting results from one year from results from another 
year. (Classified saltmarsh present in both years = "stable", classified saltmarsh present in earlier year but not in 
- later year = "loss", classified saltmarsh present in later year but not in earlier year = "gain".)
- Absolute extents can only be estimated with detailed manual checks for mis-classified areas. 
