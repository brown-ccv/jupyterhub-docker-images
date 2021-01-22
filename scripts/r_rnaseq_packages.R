# R packages for RNA sequence workshop part 1 

install.packages(c("ggplot2", "pheatmap", "RColorBrewer", "PoiClaClu",
                   "patchwork", "BiocManager", "tidyr", "GGally"), dependencies=TRUE, 
                 repos='http://cran.rstudio.com/')
BiocManager::install(c("airway", "DESeq2", "vsn", "biomaRt",
                       "AnnotationHub", "SummarizedExperiment"))
