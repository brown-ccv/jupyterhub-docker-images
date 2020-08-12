# Docker Images for Brown's JupyterHub

## Overview
This document outlines the process for creation of Docker images for JupyterHub at Brown. Every semester multiple courses request a JupyterHub, we build one image for each of those courses based on requirements specified in the request.
We use Github Actions and Docker Compose to create the environments, build, and push the docker images. 

## The GH Actions way
To create an image to be used in JupyterHub for a particular class, we need these components:

### Shared components
- `Dockerfile`: the base dockerfile to create the image. [The file currently being is a modification of the official Jupyter `base-notebook` image.](https://github.com/jupyter/docker-stacks/blob/master/base-notebook/Dockerfile)

- `docker-compose.yml`: docker compose file with three services. The first two steps are used to create environment files for conda and julia respectively. This step will generate and write conda's and julia's environment files. These files will be uploaded as artifacts so students can use them to reproduce the JH environment. The third step uses the environment files generated in steps one and two to build the image and push to GCR (Google Container Registry). 
- `scripts/`: contains the scripts needed by the image. Currently it has scripts needed by the Berkley image and the ones needed for the Jupyter official images.
- `requirements/common/`: contains `requirements.txt` (list of packages to isntall from conda-forge) and `requirements.pip.txt` (list of packages to install using pip). Those files will be appended to the class-specific `requirement*` files.

### Class-specific components
Each class has the following exclusive components:
- `requirements/classes/${className}/`:  the requirement files with the class-specific packages needed to create the conda environment. The  `requirements.txt` (requirede) – list of packages to isntall from conda-forge. `requirements.pip.txt` (optional) – list of packages to install using pip. `requirements.jl` (optional) – julia file with `const julia_packages = []`, with an array of packages to install.
- `.github/workflow/className.yml`: the github action workflow. One workflow per class will make the environment files artifacts easier to find. In addition, it allows us to run the workflow conditionally on changes related to a single class. The last step requires specific environment variables. At least `CLASS::str` and `TARGET::str` need to be passed, where CLASS is the class name (e.g. data1010) and target is the stage in the docker file to target: `base` (only python), `r_lang` (Python and R), `r_julia` (Python, R, and Julia). The variable `WITH_MYSQL::bool` will be used to conditionally run steps to install MySQL.

### Usage
> Note: The production image will be created in CI.

To add a new class:
- Create a directory with the class code under `requirements/classes/` and add the requirements file(s). See options above.
- Create a workflow file `className.yml` in `.github/workflows`. Use the provided script in `dev/generate_workflow.sh`. The script takes three arguments class name (string): `-c`, target in docker file (string): `-t` and wheter to install mysql `-m` (ommit the `-m` tag if mysql is not required).

```bash
# e.g
./generate-wrokflow.sh -c data1010 -t r_julia
```

To build the images locally:

- Create the environment files:
```
CLASS=apma0360 docker-compose up conda_build
CLASS=apma0360 docker-compose up julia_build
```
- Build JH Image
```
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 CLASS=apma0360 TARGET=base docker-compose build jh_image
```
- Run the image
```
docker run -it --rm -p 8888:8888 jupyterhub-conda-envs_jh_image start-notebook.sh --ip 0.0.0.0
```

### General Notes
The actions running on push will allow for a streamlined development, however, I would suggest that we tag releases for the images that are officially being used in production. The release workflow is not part of this PR and still needs to be created.

This process also can be moved to the same repo as the actual JupyterHub deployment code.

The secrets needed for this action were added to the Organization level, so they can easily be reused in case we create different repos.