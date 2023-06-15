# Docker Images for Brown's JupyterHub

---

## For Users

#### Docker Images

[See a list of the Docker images here.](https://console.cloud.google.com/gcr/images/jupyterhub-docker-images)

To use one of those images locally:
- [Install Google Cloud SDK](https://cloud.google.com/sdk/docs/downloads-interactive)
- Configure docker to use the gcloud command-line tool as a credential helper:
```
gcloud auth configure-docker
```
- Run the image locally:

```
# example
docker run -it --rm -p 8888:8888 gcr.io/jupyterhub-docker-images/mpa2065:latest
```

#### Environment Files

We provide Conda and Julia environemnt files if you wish to recreate the JupyterHub environment locally.
These files are available for download [from this Google Storage Bucket](https://console.cloud.google.com/storage/browser/jupyterhub-environment-files).


## For Developers

### Overview
This document outlines the process for creation of Docker images for JupyterHub at Brown. Every semester multiple courses request a JupyterHub, we build one image for each of those courses based on requirements specified in the request.
We use Github Actions and Docker Compose to create the environments, build, and push the docker images. 

### The GH Actions way
To create an image to be used in JupyterHub for a particular class, we need these components:

#### Shared components
- `Dockerfile`: the base dockerfile to create the image. [The file currently being is a modification of the official Jupyter `base-notebook` image.](https://github.com/jupyter/docker-stacks/blob/master/base-notebook/Dockerfile)

- `docker-compose.yml`: docker compose file with three services. The first two steps are used to create environment files for conda and julia respectively. This step will generate and write conda's and julia's environment files. These files will be uploaded as artifacts so students can use them to reproduce the JH environment. The third step uses the environment files generated in steps one and two to build the image and push to GCR (Google Container Registry). 
- `scripts/`: contains the scripts needed by the image. Currently it has scripts needed by the Berkley image and the ones needed for the Jupyter official images.
- `requirements/common/`: contains `requirements.txt` (list of packages to install from conda-forge) and `requirements.pip.txt` (list of packages to install using pip). Those files will get installed in the base environment.

### Class-specific components
Each class has the following exclusive components:
- `requirements/classes/${className}/`:  the requirement files with the class-specific packages needed to create the conda environment. 
    - `requirements.txt` (requiered) – list of packages to isntall from conda-forge. 
    - `requirements.pip.txt` (optional) – list of packages to install using pip. 
    - `requirements.jl` (optional) – julia file with `const julia_packages = []`, with an array of packages to install.
    - `condarc` (required) - conda configuration file listing channels for installation. By default the only channel is `conda-forge`
- `.github/workflow/className.yml` and `.github/workflow/className-tag.yml` : the github action workflow. One workflow per class will make the environment files artifacts easier to find. In addition, it allows us to run the workflow conditionally on changes related to a single class. The last step requires the followign environment variables to be set accondingly. 

> Note: The production image will be created in CI.

To add a new class:
- Use the provided script in `dev/add_class.sh` to create a workflow file and scafold the requirements directory. The script takes the following arguments: 
 - `-c`: class name (string) 
 - `-s`: class season/semester (fall, summer, spring) 
 - `-t`: target in docker file (string  – `base`, `r_lang` or `r_julia`) 
 - `-p`: python version (i.e 3.9 if ommited defaults to 3.10)
 - `-q`: wheter to install sqlite kernel (ommit the `-q` tag if sqlite is not required)

The example below shows creating a class specifying an older version of python (3.9). Omitting the `-p` argument will use the default version (currently 3.10). The default python is configured in the `docker-compose.yml`.
```bash
# e.g
cd dev/
./add_class.sh -c data1010 -t r_julia -s fall -p 3.9 -q
```

To build the images locally:

- Create the environment files (only required if if TARGET is `r_julia`):
```
CLASS=apma0360 docker-compose up julia_build
```
- Build JH Image
```
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 CLASS=apma0360 TARGET=base docker-compose up jh_image
or
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 CLASS=apma0360 TARGET=base SQLITE=true docker-compose up jh_image
```
- Run the image
```
docker run -it --rm -p 8888:8888 jupyterhub-docker-images_jh_image
```

