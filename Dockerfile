# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG ROOT_CONTAINER="jupyter/base-notebook:latest"
FROM ${ROOT_CONTAINER} as base

ARG CLASS

##### VSCODE ######################################################################
USER root
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    git \
    openssh-client \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV VS_CODE_VERSION=3.4.1

RUN mkdir /opt/code-server 
WORKDIR /opt/code-server 
RUN wget -qO- https://github.com/cdr/code-server/releases/download/${VS_CODE_VERSION}/code-server-${VS_CODE_VERSION}-linux-x86_64.tar.gz | tar zxvf - --strip-components=1
ENV	PATH=/opt/code-server:$PATH

#####################################################################################

USER $NB_UID
WORKDIR $HOME

####################################################################
# Create Conda environment

# COPY requirements/out/environment.yml /home/$NB_USER/tmp/
COPY requirements/classes/${CLASS} /home/$NB_USER/tmp/

RUN conda create --name ${CLASS} python=3.8 && \
    conda install -y --name ${CLASS} -c conda-forge --file /home/$NB_USER/tmp/requirements.txt && \
    source activate ${CLASS} && \
    pip install -r /home/$NB_USER/tmp/requirements.pip.txt && \
    conda clean --all -f -y

# RUN cd /home/$NB_USER/tmp/ && \
#     conda env create -p $CONDA_DIR/envs/${CLASS} -f environment.yml && \
#     conda clean --all -f -y

# Modify the path directly since the `source activate ${CLASS}`
# environment won't be preserved here.
ENV PATH ${CONDA_DIR}/envs/${CLASS}/bin:$PATH
ENV CONDA_DEFAULT_ENV ${CLASS}

# Link conda environment to Jupyter
RUN $CONDA_DIR/envs/${CLASS}/bin/python -m ipykernel install --user --name=${CLASS} && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN jupyter labextension install @jupyterlab/server-proxy 
RUN jupyter lab build --dev-build=False --minimize=False
 
# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

WORKDIR $HOME


####################################################################
# Add R pre-requisites
FROM base as r_lang

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG CLASS

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    unixodbc \
    unixodbc-dev \
    r-cran-rodbc \
    gfortran \
    gcc && \
    rm -rf /var/lib/apt/lists/*

# Fix for devtools https://github.com/conda-forge/r-devtools-feedstock/issues/4
RUN ln -s /bin/tar /bin/gtar

USER $NB_UID
WORKDIR $HOME

####################################################################
# Add Julia pre-requisites
FROM r_lang as r_julia

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG CLASS

USER root
# Julia dependencies

ENV JULIA_DEPOT_PATH=$HOME/.julia/
ENV JULIA_PKGDIR=$HOME/.julia/
ENV JULIA_VERSION=1.5.0

RUN mkdir $HOME/.julia/
COPY requirements/classes/${CLASS}/julia_env/Project.toml $HOME/.julia/environments/v1.5/
COPY requirements/classes/${CLASS}/julia_env/Manifest.toml $HOME/.julia/environments/v1.5/
RUN fix-permissions ${JULIA_PKGDIR}

WORKDIR /tmp

# hadolint ignore=SC2046
RUN mkdir "/opt/julia-${JULIA_VERSION}" && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/$(echo "${JULIA_VERSION}" | cut -d. -f 1,2)"/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" && \
    echo "be7af676f8474afce098861275d28a0eb8a4ece3f83a11027e3554dcdecddb91 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -C "/opt/julia-${JULIA_VERSION}" --strip-components=1 && \
    rm "/tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    chown "${NB_USER}" "${JULIA_PKGDIR}" 


USER $NB_UID

# Add Julia packages. Instantiate Julia env from files.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update(); Pkg.instantiate(); Pkg.precompile();'


USER $NB_UID
WORKDIR $HOME

