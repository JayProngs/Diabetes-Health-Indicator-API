# Use an ARM64-compatible base image
FROM rocker/r-ver:4.3.1

# Install essential build tools and libraries
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    libcurl4-gnutls-dev \
    libssl-dev \
    libsodium-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    git \
    curl

# Install the 'pak' package
RUN R -e "install.packages('pak', repos = 'https://cran.rstudio.com')"

# Install R packages using 'pak'
RUN R -e "pak::pkg_install(c('plumber', 'tidyverse', 'tidymodels', 'ranger', 'yardstick', 'ggplot2'))"

# Copy your API script and dataset into the Docker image
COPY api.R /api.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

# Expose port 8000 for the API
EXPOSE 8000

# Set the command to run the API when the container starts
CMD ["R", "-e", "pr <- plumber::plumb('/api.R'); pr$run(host='0.0.0.0', port=8000)"]
