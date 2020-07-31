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