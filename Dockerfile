# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG ROOT_CONTAINER="ubuntu:focal-20200703@sha256:d5a6519d9f048100123c568eb83f7ef5bfcad69b01424f420f17c932b00dea76"
FROM ${ROOT_CONTAINER} as base

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG CLASS

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    curl \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    run-one \
    git \
    openssh-client \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# Copy a script that we will use to correct permissions after running certain commands
COPY scripts/fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR

##### VSCODE ######################################################################
ENV VS_CODE_VERSION=3.4.1

RUN mkdir /opt/code-server 
WORKDIR /opt/code-server 
RUN wget -qO- https://github.com/cdr/code-server/releases/download/${VS_CODE_VERSION}/code-server-${VS_CODE_VERSION}-linux-x86_64.tar.gz | tar zxvf - --strip-components=1
ENV	PATH=/opt/code-server:$PATH

#####################################################################################

USER $NB_UID
WORKDIR $HOME

ARG PYTHON_VERSION=default

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work && \
    fix-permissions /home/$NB_USER

####################################################################
# Download, install and configure the Conda environment
WORKDIR /tmp

RUN curl -o /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh

# Install miniconda
RUN bash /tmp/miniconda.sh -b -u -p $CONDA_DIR

# Encapsulate the environment info into its own yml file (which carries
# the name `${CLASS}` in it

COPY requirements/out/environment.yml /tmp/
RUN conda config --set always_yes yes --set changeps1 no && \
    conda update -q conda && \
    conda config --add channels conda-forge && \
    conda env create -f /tmp/environment.yml && \
    conda clean --all -f -y && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER 

# Modify the path directly since the `source activate ${CLASS}`
# environment won't be preserved here.
ENV PATH ${CONDA_DIR}/envs/${CLASS}/bin:$PATH
ENV CONDA_DEFAULT_ENV ${CLASS}

# Set bash as shell in terminado.
ADD scripts/jupyter_notebook_config.py  ${CONDA_DIR}/envs/${CLASS}/etc/jupyter/

# Disable history.
ADD scripts/ipython_config.py ${CONDA_DIR}/envs/${CLASS}/etc/ipython/

RUN jupyter labextension install @jupyterlab/server-proxy 
RUN jupyter lab build --dev-build=False --minimize=False
 
EXPOSE 8888

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Copy local files as late as possible to avoid cache busting
COPY scripts/start.sh scripts/start-notebook.sh scripts/start-singleuser.sh /usr/local/bin/
COPY scripts/jupyter_notebook_config.py /etc/jupyter/

# Fix permissions on /etc/jupyter as root
USER root
RUN chmod +x /usr/local/bin/start-notebook.sh && \
    chmod +x /usr/local/bin/start-singleuser.sh && \
    chmod +x /usr/local/bin/start.sh

RUN fix-permissions /etc/jupyter/

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

