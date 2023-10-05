# See https://medium.com/@hdpoorna/deploying-an-r-shiny-dashboard-on-gcp-cloud-run-c1c32a076783

# get shiny server plus tidyverse packages image
FROM rocker/shiny-verse:latest

RUN mkdir -p /opt/services/shinyapp/src
WORKDIR /opt/services/shinyapp/src/
# system libraries
# Try to only install system libraries you actually need
# Package Manager is a good resource to help discover system deps
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libssl-dev

# install R packages required 
# Change the packages list to suit your needs

RUN R -e 'install.packages(c(\
              "shinydashboard", \
              "plotly", \
              "scales", \
              "lubridate", \
              "ggrepel", \
              "shiny.i18n", \
              "DT", \
              "ggiraph"))'
# clean up
RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds

COPY . /opt/services/shinyapp/src

EXPOSE 8100
CMD R -e "shiny::runApp(appDir='shinyapp', port=8100, host='0.0.0.0')"