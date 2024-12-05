# Using base R because other image was unsupported with Apple Silicone.
FROM rocker/r-ver:4.3.1
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

# Used to install dependencies
RUN R -e "install.packages('pak', repos = 'https://cran.rstudio.com')"
RUN R -e "pak::pkg_install(c('plumber', 'tidyverse', 'tidymodels', 'ranger', 'yardstick', 'ggplot2'))"

COPY api.R /api.R
COPY diabetes_binary_health_indicators_BRFSS2015.csv /diabetes_binary_health_indicators_BRFSS2015.csv

EXPOSE 8000
CMD ["R", "-e", "pr <- plumber::plumb('/api.R'); pr$run(host='0.0.0.0', port=8000)"]
