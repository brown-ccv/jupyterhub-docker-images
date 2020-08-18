# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG ROOT_CONTAINER="jupyter/base-notebook:latest"
FROM ${ROOT_CONTAINER} as base

ARG CLASS

#------------ Install VSCode Server a Root----------------------------
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

#------------ Install Lab Extensions in base environment as NB_USER----------------------------


USER $NB_UID
WORKDIR $HOME

# Install Git extension
RUN jupyter labextension install @jupyterlab/git && \
    pip install --upgrade jupyterlab-git && \
    jupyter serverextension enable --py jupyterlab_git --sys-prefix &&\
    npm cache clean --force

# Install nbgitpuller extension
RUN pip install nbgitpuller && \
    jupyter serverextension enable --py nbgitpuller --sys-prefix && \
    npm cache clean --force

# Install RISE extension
RUN pip install RISE && \
    jupyter nbextension install rise --py --sys-prefix &&\
    jupyter nbextension enable rise --py --sys-prefix &&\
    npm cache clean --force


# Do we need any of these? Seems too much...
# # Install JupyterLab extensions 
# RUN jupyter labextension install \
#             @jupyterlab/vega2-extension \
#             @jupyterlab/vega3-extension \
#             @jupyter-widgets/jupyterlab-manager \
#             jupyter-matplotlib \
#             @jupyterlab/plotly-extension \
#             @jupyterlab/geojson-extension \
#             @jupyterlab/mathjax3-extension \
#             @jupyterlab/katex-extension

#Install VS Code
RUN pip install jupyter-server-proxy
RUN jupyter serverextension enable --sys-prefix --py jupyter_server_proxy
RUN jupyter labextension install @jupyterlab/server-proxy 
#Install VSCode Proxy
RUN pip install git+https://github.com/betatim/vscode-binder


####################################################################
# Create Class Conda environment

# COPY requirements/out/environment.yml /home/$NB_USER/tmp/

COPY requirements/classes/${CLASS} /home/$NB_USER/tmp/

RUN conda create --quiet --yes -p ${CONDA_DIR}/envs/${CLASS} python=3.8 && \
    conda install -y --name ${CLASS} -c conda-forge --file /home/$NB_USER/tmp/requirements.txt && \
    conda clean --all -f -y

# Link conda environment to Jupyter system-wide
USER root
RUN $CONDA_DIR/envs/${CLASS}/bin/python -m ipykernel install --name=${CLASS}
USER $NB_USER

# Modify the path directly since the `source activate ${CLASS}`
# environment won't be preserved here.
ENV PATH ${CONDA_DIR}/envs/${CLASS}/bin:$PATH


# Class-specific pip installs 
RUN $CONDA_DIR/envs/${CLASS}/bin/pip install -r /home/$NB_USER/tmp/requirements.pip.txt  && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# make class environment to be the default one
ENV CONDA_DEFAULT_ENV ${CLASS}

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

