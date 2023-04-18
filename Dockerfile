# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG ROOT_CONTAINER="jupyter/base-notebook:lab-3.4.5"
FROM ${ROOT_CONTAINER} as base

ARG CLASS
ARG SQLITE
ARG PYTHON_VERSION

USER ${NB_UID}
RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

USER root
# RUN apt-get update && \
#     apt-get install -y software-properties-common && \
#     add-apt-repository universe && \
#     add-apt-repository ppa:git-core/ppa && \
#     apt update

USER ${NB_UID}
RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

USER root

RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    vim \
    emacs \
    ripgrep \
    fd-find \
    nano-tiny \
    tzdata \
    less \
    git \
    wget \
    unzip \
    openssh-client \
    # nbconvert dependencies
    # https://nbconvert.readthedocs.io/en/latest/install.html#installing-tex
    texlive-xetex \
    texlive-latex-recommended \
    texlive-fonts-recommended \
    texlive-plain-generic \
    pandoc \
    dvipng \
# single cell dependencies 
    libboost-all-dev \
    libcurl4-openssl-dev \
    libfftw3-dev \
    libgeos-dev \
    libgsl-dev \
    libhdf5-dev \
    libpng-dev \
    libxml2-dev \
    libffi-dev \
    pkg-config \
    openjdk-8-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

#also for single cell
RUN apt-get install -y llvm-10

# Install FIt-SNE also for single cell
RUN git clone --branch v1.2.1 https://github.com/KlugerLab/FIt-SNE.git
RUN g++ -std=c++11 -O3 FIt-SNE/src/sptree.cpp FIt-SNE/src/tsne.cpp FIt-SNE/src/nbodyfft.cpp  -o bin/fast_tsne -pthread -lfftw3 -lm

USER ${NB_UID}
RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

USER root

# Install missing fonts
RUN cd /usr/share/fonts && \
    wget http://mirrors.ctan.org/fonts/tex-gyre/opentype/texgyrepagella-bold.otf && \
    wget http://mirrors.ctan.org/fonts/tex-gyre/opentype/texgyrepagella-bolditalic.otf && \
    wget http://mirrors.ctan.org/fonts/tex-gyre/opentype/texgyrepagella-italic.otf && \
    wget http://mirrors.ctan.org/fonts/tex-gyre/opentype/texgyrepagella-regular.otf && \
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSansMono-unhinted.zip && \
    unzip NotoSansMono-unhinted.zip && \
    chmod +r -R /usr/share/fonts

RUN fc-cache -fsv 
RUN mktexlsr

#------------ Install VSCode Server a Root----------------------------

ENV VS_CODE_VERSION=4.5.1
RUN mkdir /opt/code-server 
WORKDIR /opt/code-server 
RUN wget -qO- https://github.com/coder/code-server/releases/download/v${VS_CODE_VERSION}/code-server-${VS_CODE_VERSION}-linux-amd64.tar.gz | tar zxvf - --strip-components=1
ENV	PATH=/opt/code-server:$PATH

#------------ Install Lab Extensions in base environment as NB_USER----------------------------


USER ${NB_UID}

RUN ls -la

RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

COPY requirements/common/ /tmp/
RUN mamba install -y -c conda-forge --file /tmp/requirements.txt && \
    mamba clean --all -f -y

RUN ls -la

RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"


RUN if [ "$SQLITE" = "true" ] ; then \
    mamba install -y -c conda-forge xeus-sqlite && \
    mamba clean --all -f -y ; \
    fi 

# Install jupyterlab git extension, this must come before installing extensions with pip (layer below)
# RUN jupyter labextension install '@jupyterlab/git' --no-build && \
#     npm cache clean --force

RUN pip install --upgrade -r /tmp/requirements.pip.txt

RUN fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Install and Enable Extensions
# RUN jupyter serverextension enable --py 'jupyterlab_git' --sys-prefix && \
#     jupyter serverextension enable --py 'nbgitpuller' --sys-prefix && \
#     jupyter nbextension install 'rise' --py --sys-prefix && \
#     jupyter nbextension enable 'rise' --py --sys-prefix && \
#     jupyter serverextension enable --sys-prefix --py 'jupyter_server_proxy' && \
#     jupyter labextension install '@jupyterlab/server-proxy' --no-build && \
#     jupyter nbextension install 'jupytext' --py --sys-prefix && \
#     jupyter nbextension enable 'jupytext' --py --sys-prefix && \
#     # jupyter serverextension enable --sys-prefix 'jupyterlab_latex' && \
#     # jupyter labextension install '@jupyterlab/latex' --no-build && \
#     # jupyter labextension install '@jupyter-widgets/jupyterlab-manager@2.0' 'jupyter-matplotlib@0.7.3' --no-build && \
#     jupyter lab build && \
#     jupyter lab clean -y && \
#     npm cache clean --force && \
#     rm -rf "/home/${NB_USER}/.cache/yarn" && \
#     rm -rf "/home/${NB_USER}/.node-gyp" && \
#     fix-permissions "${CONDA_DIR}"  && \
#     fix-permissions "/home/${NB_USER}"


# Overwrite default latex/jupyter template to include above fonts    
COPY --chown=${NB_UID}:${NB_GID} scripts/style_jupyter.tplx /opt/conda/lib/python3.10/site-packages/nbconvert/templates/latex/style_jupyter.tplx

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# De-activate the default kernel spec
COPY scripts/jupyter_config.py /etc/jupyter/jupyter_config.py
RUN jupyter kernelspec remove -f python3
####################################################################
# Create Class Conda environment

COPY --chown=${NB_UID}:${NB_GID} requirements/classes/${CLASS} /home/$NB_USER/tmp/
COPY --chown=${NB_UID}:${NB_GID} requirements/classes/${CLASS}/condarc /home/$NB_USER/.mambarc

RUN mamba create --quiet --yes -p ${CONDA_DIR}/envs/${CLASS} python=${PYTHON_VERSION} && \
    mamba install -y --name ${CLASS} --file /home/$NB_USER/tmp/requirements.txt && \
    mamba clean --all -f -y

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Link conda environment to Jupyter system-wide
USER root
RUN $CONDA_DIR/envs/${CLASS}/bin/python -m ipykernel install --name=${CLASS} --display-name "Python 3"
RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

USER $NB_USER

# Modify the path directly since the `source activate ${CLASS}`
# environment won't be preserved here.
ENV PATH ${CONDA_DIR}/envs/${CLASS}/bin:$PATH

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

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

RUN mamba install -y -p ${CONDA_DIR} -c conda-forge r-irkernel && \
    mamba clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install necessary R packages along with their dependencies
RUN Rscript /home/$NB_USER/tmp/packages.R


####################################################################
# Add Julia pre-requisites
FROM r_lang as r_julia

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG CLASS

USER root
# Julia dependencies

ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.8.5
ENV JULIA_TAG=v1.8

COPY requirements/classes/${CLASS}/julia_env/Project.toml $JULIA_PKGDIR/environments/$JULIA_TAG/
COPY requirements/classes/${CLASS}/julia_env/Manifest.toml $JULIA_PKGDIR/environments/$JULIA_TAG/
RUN fix-permissions ${JULIA_PKGDIR}

WORKDIR /tmp

# hadolint ignore=SC2046
RUN mkdir "/opt/julia-${JULIA_VERSION}" && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/$(echo "${JULIA_VERSION}" | cut -d. -f 1,2)"/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" && \
    echo "e71a24816e8fe9d5f4807664cbbb42738f5aa9fe05397d35c81d4c5d649b9d05 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
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
RUN julia -e 'import Pkg; Pkg.update()' && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \
    # move kernelspec out of home \
    mv "${HOME}/.local/share/jupyter/kernels/julia"* "${CONDA_DIR}/share/jupyter/kernels/" && \
    chmod -R go+rx "${CONDA_DIR}/share/jupyter" && \
    rm -rf "${HOME}/.local" && \
    fix-permissions "${JULIA_PKGDIR}" "${CONDA_DIR}/share/jupyter"

RUN julia -e 'import Pkg; Pkg.update(); Pkg.instantiate(); Pkg.precompile();' && \
    julia -e "using Pkg; pkg\"add WebIO\"" 

USER root
RUN /opt/conda/bin/python -m pip install webio_jupyter_extension
USER $NB_UID

ENV JULIA_DEPOT_PATH="$HOME/.julia:$JULIA_DEPOT_PATH"

USER $NB_UID
WORKDIR $HOME

