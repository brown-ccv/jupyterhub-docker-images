# Use this script to install packages via CRAN, for example: 

# NOTE: Code below shows how you install R packages from CRAN and Bioconductor. For CRAN packages, you can use 
# the standard install.packages() function; for Bioconductor packages, however, you 
# must first install BiocManager and then use that for installs. 

install.packages(c("tidyverse", ("BiocManager"), dependencies=TRUE, repos='http://cran.rstudio.com/')

install.packages(c("GGally", "ggrepel", "kableExtra", "knitr", "maps", "openxlsx", "patchwork", "pdftools", "pheatmap", "pillar", "plotly", "R.utils", "R2HTML", "RColorBrewer", "remotes", "rgeos", "spatstat.explore", "spatstat.geom", "stringr", "viridis", "tesseract","zoo", "gridExtra"), repos = "http://cran.rstudio.com/", dependencies = TRUE)
