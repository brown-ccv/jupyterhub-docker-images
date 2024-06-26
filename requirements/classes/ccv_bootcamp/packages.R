# Use this script to install packages via CRAN, for example: 

# NOTE: Code below shows how you install R packages from CRAN and Bioconductor. For CRAN packages, you can use 
# the standard install.packages() function; for Bioconductor packages, however, you 
# must first install BiocManager and then use that for installs. 

# install.packages("BiocManager", dependencies=TRUE, repos='http://cran.rstudio.com/')
# install.packages(c("ggplot2", "pheatmap", "RColorBrewer", "PoiClaClu",
#                    "patchwork", "tidyr", "GGally"), dependencies=TRUE, 
#                  repos='http://cran.rstudio.com/')
# BiocManager::install(c("airway", "DESeq2", "vsn", "biomaRt",
#                        "AnnotationHub", "SummarizedExperiment"))

install.packages("BiocManager", dependencies=TRUE, repos='http://cran.rstudio.com/')
install.packages(c("tidyverse"), dependencies=TRUE, repos='http://cran.rstudio.com/')
install.packages(c( "ape", "arrow", "deldir", "devtools", "doMC", 
                    "doRNG", "DT", "enrichR", "ggrepel", "hdf5r",
                    "kableExtra", "knitr", "maps", "Matrix", "metap", 
                    "mixtools", "NMF", "openxlsx", "parallel", "patchwork", 
                    "pdftools", "pheatmap", "plotly", "PoiClaClu", "purrr", 
                    "R.utils", "R2HTML", "RColorBrewer", "RcppArmadillo", "remotes", 
                    "Rfast2", "rgeos", "rsvd", "Rtsne", "sctransform", "Seurat", 
                    "spatstat.explore", "spatstat.geom", "stringr", "VGAM", "viridis",
                    "zoo"),  repos = "http://cran.rstudio.com/",  dependencies = TRUE)
BiocManager::install(c("airpart", "airway", "AnnotationHub", "AUCell", "batchelor", 
                       "Biobase", "BiocGenerics", "biomaRt", "BSgenome", "BSgenome.Hsapiens.UCSC.hg19",
                       "clusterProfiler", "ComplexHeatmap", "DelayedArray", "DelayedMatrixStats", "DESeq2", 
                       "DOSE", "enrichplot", "ensembldb", "GENIE3", "GenomicFeatures", 
                       "GenomeInfoDb", "GenomicRanges", "glmGamPoi", "IRanges", 
                       "JASPAR2022", "limma", "MAST", "monocle", "multtest", 
                       "RcisTarget", "RnaSeqSampleSize", "rtracklayer", "S4Vectors", "scater", 
                       "SingleCellExperiment", "SummarizedExperiment", "TFBSTools", "vsn", "WGCNA"))
remotes::install_github("mojaveazure/seurat-disk")
remotes::install_github("satijalab/seurat-data")
remotes::install_github("brendankelly/micropower")