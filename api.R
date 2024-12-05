library(plumber)
library(tidyverse)
library(tidymodels)
library(ranger)
library(yardstick)
library(ggplot2)

# Load and preprocess the data
data <- read_csv("diabetes_binary_health_indicators_BRFSS2015.csv")

# Convert variables to factors with labels
data <- data %>%
  mutate(
    Diabetes_binary = factor(Diabetes_binary, labels = c("No", "Yes")),
    HighBP = factor(HighBP, labels = c("No", "Yes")),
    HighChol = factor(HighChol, labels = c("No", "Yes")),
    CholCheck = factor(CholCheck, labels = c("No", "Yes")),
    Smoker = factor(Smoker, labels = c("No", "Yes")),
    Stroke = factor(Stroke, labels = c("No", "Yes")),
    HeartDiseaseorAttack = factor(HeartDiseaseorAttack, labels = c("No", "Yes")),
    PhysActivity = factor(PhysActivity, labels = c("No", "Yes")),
    Fruits = factor(Fruits, labels = c("No", "Yes")),
    Veggies = factor(Veggies, labels = c("No", "Yes")),
    HvyAlcoholConsump = factor(HvyAlcoholConsump, labels = c("No", "Yes")),
    AnyHealthcare = factor(AnyHealthcare, labels = c("No", "Yes")),
    NoDocbcCost = factor(NoDocbcCost, labels = c("No", "Yes")),
    DiffWalk = factor(DiffWalk, labels = c("No", "Yes")),
    Sex = factor(Sex, labels = c("Female", "Male"))
  ) %>%
  mutate(
    GenHlth = factor(
      GenHlth,
      ordered = TRUE,
      levels = c(1, 2, 3, 4, 5),
      labels = c("Excellent", "Very Good", "Good", "Fair", "Poor")
    ),
    Age = factor(
      Age,
      ordered = TRUE,
      levels = 1:13,
      labels = c(
        "18-24",
        "25-29",
        "30-34",
        "35-39",
        "40-44",
        "45-49",
        "50-54",
        "55-59",
        "60-64",
        "65-69",
        "70-74",
        "75-79",
        "80 or older"
      )
    ),
    Education = factor(
      Education,
      ordered = TRUE,
      levels = 1:6,
      labels = c(
        "No schooling",
        "Elementary",
        "Some high school",
        "High school graduate",
        "Some college",
        "College graduate"
      )
    ),
    Income = factor(
      Income,
      ordered = TRUE,
      levels = 1:8,
      labels = c(
        "<$10,000",
        "$10,000-$15,000",
        "$15,000-$20,000",
        "$20,000-$25,000",
        "$25,000-$35,000",
        "$35,000-$50,000",
        "$50,000-$75,000",
        "≥$75,000"
      )
    )
  )

recipe <- recipe(Diabetes_binary ~ BMI + Age + HighBP + PhysActivity + GenHlth, data = data) %>%
  step_dummy(all_nominal_predictors()) |>
  step_interact()

prepped_recipe <- prep(recipe)

# Fit the final Random Forest model on the entire dataset
final_rf_model <- rand_forest(mtry = 4, # 4 is best mtry value from Modelling.qmd
                              trees = 1000) %>%
  set_engine("ranger", importance = "impurity") %>%
  set_mode("classification")

workflow <- workflow() %>%
  add_model(final_rf_model) %>%
  add_recipe(recipe)

final_rf_fit <- workflow %>%
  fit(data = data)

#' @apiTitle Diabetes Prediction API

#' Predict the probability of having diabetes
#' @param HighBP High blood pressure (No/Yes)
#' @param BMI Body Mass Index (numeric)
#' @param PhysActivity Physical activity (No/Yes)
#' @param GenHlth General health status (Excellent to Poor)
#' @param Age Age category (e.g., '18-24')
#' @get /pred
function(HighBP = "Yes",
         BMI = 28.0,
         PhysActivity = "Yes",
         GenHlth = "Good",
         Age = "55-59") {
  library(tibble)
  
  input_data <- tibble(
    HighBP = factor(HighBP, levels = c("No", "Yes")),
    BMI = as.numeric(BMI),
    PhysActivity = factor(PhysActivity, levels = c("No", "Yes")),
    GenHlth = factor(
      GenHlth,
      levels = c("Excellent", "Very Good", "Good", "Fair", "Poor"),
      ordered = TRUE
    ),
    Age = factor(
      Age,
      levels = c(
        "18-24",
        "25-29",
        "30-34",
        "35-39",
        "40-44",
        "45-49",
        "50-54",
        "55-59",
        "60-64",
        "65-69",
        "70-74",
        "75-79",
        "80 or older"
      ),
      ordered = TRUE
    )
  )
  
  # Use the trained recipe to transform the input data
  # baked_data <- bake(prepped_recipe, new_data = input_data)
  
  # Predict probabilities using the fitted model and return
  prediction <- predict(final_rf_fit, new_data = input_data, type = "prob")
  list(probability_of_diabetes = prediction$.pred_Yes)
}



#' Provide information about the API
#' @get /info
function() {
  list(name = "Jay", github_pages_url = "https://jayprongs.github.io/Diabetes-Health-Indicator-API/EDA.html")
}

#' Plot the confusion matrix of the model
#' @png
#' @get /confusion
function() {
  # Predict on the entire dataset
  predictions <- predict(final_rf_fit, data)
  
  # Combine predictions with true value
  results <- tibble(truth = data$Diabetes_binary,
                    prediction = predictions$.pred_class)
  
  # Generate and plot confusion matrix
  cm <- conf_mat(results, truth = truth, estimate = prediction)
  plot <- autoplot(cm, type = "heatmap") + theme_minimal()
  print(plot)
}


# Example API calls:
# http://localhost:8000/pred?HighBP=Yes&BMI=32&PhysActivity=No&GenHlth=Fair&Age=60-64
# http://localhost:8000/pred?HighBP=No&BMI=22&PhysActivity=Yes&GenHlth=Excellent&Age=25-29
# http://localhost:8000/pred?HighBP=Yes&BMI=30&PhysActivity=No&GenHlth=Poor&Age=70-74
