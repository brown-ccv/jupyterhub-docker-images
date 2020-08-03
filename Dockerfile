FROM buildpack-deps:bionic-scm as base

ARG CLASS

# Set up common env variables
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV DEBIAN_FRONTEND=noninteractive

RUN adduser --disabled-password --gecos "Default Jupyter user" jovyan

# Other packages for user convenience and Data100 usage
# Install these without 'recommended' packages to keep image smaller.
RUN apt-get update -qq --yes && \
    apt-get install --yes --no-install-recommends -qq \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        default-jdk \
        emacs-nox \
        git \
        htop \
        less \
        libpq-dev \
        man \
        mc \
        nano \
        openssh-client \
        postgresql-client \
        screen \
        tar \
        tmux \
        wget \
        vim \
        locales > /dev/null

RUN apt-get update -qq --yes && \
    apt-get install --yes -qq \
        # for nbconvert
        pandoc \
        texlive-xetex \
        texlive-fonts-recommended \
        texlive-generic-recommended \
        wkhtmltopdf # for pdf export \
        > /dev/null

ENV CONDA_PREFIX /srv/conda
ENV PATH ${CONDA_PREFIX}/bin:$PATH
RUN install -d -o jovyan -g jovyan ${CONDA_PREFIX}

WORKDIR /home/jovyan

# prevent bibtex from interupting nbconvert
RUN update-alternatives --install /usr/bin/bibtex bibtex /bin/true 200


RUN ln -sf bash /bin/sh
USER jovyan

####################################################################
# Download, install and configure the Conda environment

RUN curl -o /tmp/miniconda.sh \
    https://repo.anaconda.com/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh

# Install miniconda
RUN bash /tmp/miniconda.sh -b -u -p ${CONDA_PREFIX}

RUN conda config --set always_yes yes --set changeps1 no
RUN conda update -q conda
RUN conda config --add channels conda-forge

# Encapsulate the environment info into its own yml file (which carries
# the name `${CLASS}` in it
COPY classes/${CLASS}/environment.yml /tmp/
RUN conda env create -f /tmp/environment.yml

# We modify the path directly since the `source activate ${CLASS}`
# environment won't be preserved here.
ENV PATH ${CONDA_PREFIX}/envs/${CLASS}/bin:$PATH
RUN echo $PATH

# Set bash as shell in terminado.
ADD scripts/jupyter_notebook_config.py  ${CONDA_PREFIX}/envs/${CLASS}/etc/jupyter/
# Disable history.
ADD scripts/ipython_config.py ${CONDA_PREFIX}/envs/${CLASS}/etc/ipython/

# Useful for debugging any issues with conda
RUN conda info -a

RUN jupyter lab build --dev-build=False --minimize=False

# Make JupyterHub ports visible
EXPOSE 8888

####################################################################
# Add R pre-requisites
FROM base as r_lang
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

####################################################################
# Add Julia pre-requisites
FROM r_lang as r_julia
ARG CLASS

USER root
# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.4.2

COPY classes/${CLASS}/julia_env/Project.toml /opt/julia/
COPY classes/${CLASS}/julia_env/Manifest.toml /opt/julia/

WORKDIR /tmp

# hadolint ignore=SC2046
RUN mkdir "/opt/julia-${JULIA_VERSION}" && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/$(echo "${JULIA_VERSION}" | cut -d. -f 1,2)"/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" && \
    echo "fd6d8cadaed678174c3caefb92207a3b0e8da9f926af6703fb4d1e4e4f50610a *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" -C "/opt/julia-${JULIA_VERSION}" --strip-components=1 && \
    rm "/tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir "${JULIA_PKGDIR}" && \
    chown "${NB_USER}" "${JULIA_PKGDIR}" 

USER $NB_UID

# Add Julia packages. Instantiate Julia env from files.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update(); Pkg.instantiate(); Pkg.precompile();' && \
    # move kernelspec out of home \
    mv "${HOME}/.local/share/jupyter/kernels/julia"* "${CONDA_DIR}/share/jupyter/kernels/" && \
    chmod -R go+rx "${CONDA_DIR}/share/jupyter" && \
    rm -rf "${HOME}/.local"
