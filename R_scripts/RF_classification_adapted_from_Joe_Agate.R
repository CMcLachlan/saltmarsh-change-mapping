# This script trains a Random Forest model then uses the trained model to 
# classify an image. This script has been adapted from Joe Agate's 
# UAV-salt-marsh-vegetation-communities work - 
# https://www.mdpi.com/2072-4292/18/6/866 

# Users should adapt the script to refer to imagery and sample data from their 
# study site. 


# Set up ------------------------------------------------------------------
rm(list = ls()) # clear global environment

# Load packages
#library(raster)
library(terra)
library(tidyverse)
library(ranger)
library(cowplot)
library(RColorBrewer)
library(rcartocolor)
library(caret)
library(scales)
library(here)

# Re-define select, avoids conflicts
select <- dplyr::select

# Set default plotting theme
theme_set(theme_cowplot(10))

# Reset wd to project
setwd(here())


# Import data -----------------------------------------------------------

# Import the training data - update path/file name as needed
ValueTable <- read_csv('Data/Orplands/Full_stack_Orp_2022_named.csv')


# Refactor the landcover column - update landcovers to match training data
ValueTable <- ValueTable %>%
  mutate(Landcover = factor(Landcover,
                      levels = c('Lake', 'HedgeScrub', 'Sea wall', 'Creek mud', 
                                 'Algae', 'Saltmarsh', 'Field')))


# Test/train split --------------------------------------------------------

# Set the seed for shuffling
set.seed(1)

# Randomly shuffle the data
ValueTable_shuff <- ValueTable[sample(nrow(ValueTable)), ]

# Set the seed for splitting the data
set.seed(1)

# Create a nested sample of the training quadrats
TrainingQuads <- ValueTable_shuff %>%
  distinct(Polygon_nu, Landcover) %>%
  group_by(Landcover) %>%
  sample_frac(2/3)

# Create the test/train split
TrainingData <- ValueTable_shuff %>%
  filter(Polygon_nu %in% TrainingQuads$Polygon_nu)
TestingData <- ValueTable_shuff %>%
  filter(!Polygon_nu %in% TrainingQuads$Polygon_nu)

# Clean training data
TrainingData <- TrainingData %>%
  select(DTM:Win_SRWI, Landcover) %>% # select only the training columns. 
  # Update column headings selected as needed. 
  drop_na() # drop any NAs

# Clean testing data
TestingData <- TestingData %>%
  select(DTM:Win_SRWI, Landcover) %>% # select only the training columns
  # Update column headings selected as needed. 
  drop_na() # drop any NAs



# Check contam -----------------------------------------------------------

# This just checks if there are any repeated rows in the training and testing
# data. There should not be based upon the above script, but the check is there 
# just for peace of mind

# Compare rows to check for matches
inner <- inner_join(TrainingData, TestingData, by = NULL)

# Create the warning
if(nrow(inner)>0){
  stop('Rows match between the training and testing data')
}


# Run the RF model --------------------------------------------------------

# Extract the training data X
TrainingDataX <- TrainingData %>%
  ungroup() %>%
  select(DTM:Win_SRWI) %>% # Update column headings selected as needed. 
  mutate()

# Extract the training data Y
TrainingDataY <- TrainingData$Landcover

# Train and create the RF model
RFmodelprobs <- ranger(x = TrainingDataX, y = TrainingDataY,
                  importance = "permutation", num.trees = 750, mtry=7, seed = 1,
                  probability = TRUE, trainControl(probability = TRUE))

RFmodel <- ranger(x = TrainingDataX, y = TrainingDataY,
                  importance = "permutation", num.trees = 750, mtry=7, seed = 1,
                  trainControl(savePredictions="final"))

# Query the model
RFmodel



## Validation --------------------------------------------------------------

# Predict the testing data
Prediction <- predict(RFmodel, TestingData)
Prob_prediction <- predict(RFmodelprobs, TestingData)

# Create a dataframe of class probabilities with final predictions
Class_probs <- as.data.frame(Prob_prediction$predictions)
Class_probs <- Class_probs %>%
  mutate(PredictedClass=Prediction$predictions)
Class_probs <- Class_probs %>%
  mutate(GroundTruth=TestingData$Landcover)

# Write probablilities table to csv. Update file path as needed. 
write.csv(Class_probs, "Pred_probs/2019_pred_probs_LD.csv")

# Produce a confusion matrix
confMtrx <- confusionMatrix(Prediction$predictions, TestingData$Landcover)
confMtrx

# Extract results ---------------------------------------------------------

## Plot confusion matrix ----

# Convert the confusion matrix into a data.frame
confMtrx_DF <- as.data.frame(confMtrx$table)

# Normalise the conf mtrx
confMtrx_DF <- confMtrx_DF %>%
  group_by(Reference) %>%
  mutate(Freq_n = Freq/sum(Freq))

# Plot
confMtrxplot <- confMtrx_DF %>%
  ggplot(aes(Prediction, Reference, fill = Freq_n)) +
  geom_tile(col = 'black', linewidth = .2) +
  scale_fill_carto_c(palette = 'BluYl', limits = c(0,1), direction = -1) +
  coord_equal() +
  theme(axis.line = element_blank(),
        axis.text.x = element_text(angle = 45, hjust = 0)) +
  labs(fill = NULL) +
  scale_x_discrete(position = 'top', expand = c(0,0),
                   labels = function(x) gsub('_', ' ', x)) +
  scale_y_discrete(limits = rev, expand = c(0,0),
                   labels = function(x) gsub('_', ' ', x)) +
  geom_text(data = confMtrx_DF %>% filter(round(Freq_n, 2) > 0),
            aes(label = round(Freq_n, 2)), size = 3)
confMtrxplot 

# Uncomment below and update path to export plot
#ggsave("Plots/Confusion_matrix/Orplands/2022_all_CM.png", 
#       plot = confMtrxplot, device = NULL, path = NULL,
#       scale = 1, width = 10, height = 10, units = "cm", 
#       dpi = 300, limitsize = TRUE, bg = NULL)

## Accuracy stats ----

# Source the accuracy stats function 
#(AccStats file in 
# https://github.com/joeagate/UAV-salt-marsh-vegetation-communities/tree/main)
source('Rscript/AccStats.R')

# Create accuracy stats dataframe
AccuracyStats <- AccStats(confMtrx$table)
print(AccuracyStats)


## Feature Importance ----

# Create an importance data frame
FeatureImportance <- data.frame(importance(RFmodel)) %>%
  rownames_to_column() %>%
  arrange(., importance.RFmodel.)

# Plot the results
FeatureImportance.plot <- FeatureImportance %>%
  mutate(VI = factor(FeatureImportance$rowname, 
                     levels = FeatureImportance$rowname)) %>%
  ggplot(aes(VI, importance.RFmodel.)) +
  theme_minimal() +
  geom_col(width = 0.75, fill = 'dodgerblue') +
  labs(x = 'Feature', y = 'Permutation importance') +
  theme(legend.position = 'none') +
  coord_flip() +
  scale_fill_carto_c(palette = 'Teal') +
  scale_y_continuous(expand = expansion(mult = c(0,0.1))) +
  scale_y_continuous(breaks = seq(0, 0.8, by = 0.05)) +
  scale_x_discrete(labels = function(x) gsub('_', ' ', x)) +
  theme(axis.text = element_text(size = 15)) +
  theme(axis.title = element_text(size = 15)) +
  theme(plot.title = element_text(size = 18)) 
FeatureImportance.plot

# Uncomment below and update path to export plot
#ggsave("Plots/Permutation_importance/Orplands/2022_all_PI.png", 
#       plot = FeatureImportance.plot, device = NULL, path = NULL,
#       scale = 1, width = 30, height = 20, units = "cm", dpi = 300, 
#       limitsize = TRUE, bg = NULL)

# Load the image to be classified - update path as needed
stack_image <- rast("Data/Orplands/Full_stack_Orp_2022_named.tif")

# View the image
plotRGB(stack_image, r = 1, g = 2, b = 3, stretch = "hist")

# Run the RF model on the image
# Class predictions per pixel:
pred <- predict(stack_image, RFmodel, type = "response", na.rm = TRUE)
# Class probabilities per pixel:
pred_prob <- predict(stack_image, RFmodelprobs, type = "response", na.rm = TRUE)
# Combine both prediction outputs into one raster:
pred_and_prob <- c(pred, pred_prob)

# Plot the classified image - update range to reflect number of classes
plot(pred, range = c(1,7))

# Write classified image to file - update path/filename as needed
writeRaster(pred_and_prob, 
            filename = "R_pred/Orplands/rf_pred_prob_2022_all_750_7_R.tif")