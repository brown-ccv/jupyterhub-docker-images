#!/bin/bash
set -e

usage () { echo "Usage:"
           echo "     -h – help"
           echo "     -c – Class name"
           echo "     -t – Target stage in docker file (base, r_lang, or r_julia)"
           echo "     -m – Whether to install MySQL"; }

while getopts c:t:ms:h option; do
    case "${option}" in
        c) CLASS=${OPTARG};;
        t) TARGET=${OPTARG};;
        m) WITH_MYSQL=true;;
        h) usage; exit;;
    esac
done

if [ "$WITH_MYSQL" != "true" ]; then
    WITH_MYSQL=false
fi

if ((OPTIND < 5))
then
    echo "Incomplete options specified. Make sure to pass at least the class name (-c) and target stage (-t)."
else
    echo """
name: Build Image for ${CLASS}
on: 
push:
    paths:
    - 'classes/${CLASS}/**'
    - 'Dockerfile'
    - 'docker-compose.yml'
    - 'scripts/**'
    - '.github/workflows/${CLASS}.yml'

env:
CLASS: ${CLASS}
TARGET: ${TARGET}
WITH_MYSQL: ${WITH_MYSQL}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Create Conda Environment Files
        run: |
          sudo --preserve-env=CLASS docker-compose up conda_build

      - name: Upload Cond Env Files
        uses: actions/upload-artifact@v2
        with:
          name: conda-environment-files
          path: requirements/out

      - name: Create Julia Environment Files
        run: |
          sudo --preserve-env=CLASS docker-compose up julia_build

      - name: Upload Julia Env Files
        uses: actions/upload-artifact@v2
        with:
          name: julia-environment-files
          path: requirements/classes/\${{ env.CLASS }}/julia_env

      - name: Set Up GCloud
        uses: GoogleCloudPlatform/github-actions/setup-gcloud@master
        with:
          version: '290.0.1'
          project_id: \${{ secrets.GCP_PROJECT_ID_JH_DOCKER }}
          service_account_key: \${{ secrets.GCP_SA_KEY_JH_DOCKER }}
          export_default_credentials: true

      - name: Configure Docker
        run: gcloud auth configure-docker
      - name: Build and Push JH Image
        run: |
          COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build jh_image
          docker tag jupyterhub-conda-envs_jh_image:latest gcr.io/jupyterhub-docker-images/\${CLASS}:\${GITHUB_REF##*/}
          docker tag jupyterhub-conda-envs_jh_image:latest gcr.io/jupyterhub-docker-images/\${CLASS}:\${GITHUB_SHA}
          docker tag jupyterhub-conda-envs_jh_image:latest gcr.io/jupyterhub-docker-images/\${CLASS}:latest
          docker push gcr.io/jupyterhub-docker-images/\${CLASS}:latest
          docker push gcr.io/jupyterhub-docker-images/\${CLASS}:\${GITHUB_REF##*/}
          docker push gcr.io/jupyterhub-docker-images/\${CLASS}:\${GITHUB_SHA}
    """ >> ../.github/workflows/${CLASS}.yml
    
    echo "Created workflow file at .github/workflows/${CLASS}.yml"

fi
