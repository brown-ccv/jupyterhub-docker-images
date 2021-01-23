# R packages for RNA sequence workshop part 1 

# Note that we must first install the BiocManager package in order to install packages from Bioconductor. 

install.packages("BiocManager", dependencies=TRUE, repos='http://cran.rstudio.com/')
install.packages(c("ggplot2", "pheatmap", "RColorBrewer", "PoiClaClu",
                   "patchwork", "tidyr", "GGally"), dependencies=TRUE, 
                 repos='http://cran.rstudio.com/')
BiocManager::install(c("airway", "DESeq2", "vsn", "biomaRt",
                       "AnnotationHub", "SummarizedExperiment"))
