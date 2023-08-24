#!/bin/bash
set -e

#default version of Python to use
PYTHON_VERSION=3.11.4

usage () { echo "Usage:"
           echo "     -h - help"
           echo "     -c - Class name"
           echo "     -s - Season (fall, spring, recurring)"
           echo "     -t - Target stage in docker file (base, r_lang, or r_julia)"
           echo "     -p - Python version (optional, if not given uses default)"
           echo "     -q - Whether to install SQLITE Kernel"; }

while getopts c:s:t:p:qh option; do
    case "${option}" in
        c) CLASS=${OPTARG};;
        s) SEASON=${OPTARG};;
        t) TARGET=${OPTARG};;
        p) PYTHON_VERSION=${OPTARG};;
        q) ADD_SQLITE=true;;
        h) usage; exit;;
    esac
done

if [ "$ADD_SQLITE" != "true" ]; then
    ADD_SQLITE=false
fi

if ((OPTIND < 6))
then
    echo "Incomplete options specified. Make sure to pass at least the class name (-c) and target stage (-t)."
else
    export YEAR=$(date +'%Y')
    export CLASS=$CLASS
    export TARGET=$TARGET
    export SEASON=$SEASON
    export SQLITE=$ADD_SQLITE
    export PYTHON_VERSION=${PYTHON_VERSION}
    export GITHUB_SHA="\${GITHUB_SHA}"
    envsubst < ./templates/class_workflow.yml > ../.github/workflows/${CLASS}.yml &&
    envsubst < ./templates/class_tag.yml > ../.github/workflows/${CLASS}-${SEASON}-tag.yml &&
    mkdir ../requirements/classes/${CLASS}/ &&
    cat templates/requirements.txt >> ../requirements/classes/${CLASS}/requirements.txt  &&
    cat templates/requirements.jl >> ../requirements/classes/${CLASS}/requirements.jl  &&
    cat templates/requirements.pip.txt >> ../requirements/classes/${CLASS}/requirements.pip.txt  &&
    cat templates/condarc >> ../requirements/classes/${CLASS}/condarc  &&
    cat templates/packages.R >> ../requirements/classes/${CLASS}/packages.R  &&
    echo "Created workflow file at .github/workflows/${CLASS}.yml, .github/workflows/${CLASS}-${SEASON}-tag.yml and ./requirements/classes/${CLASS}/ directory with requirement files. "
fi
