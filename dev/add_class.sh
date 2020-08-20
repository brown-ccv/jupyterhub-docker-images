#!/bin/bash
set -e

usage () { echo "Usage:"
           echo "     -h – help"
           echo "     -c – Class name"
           echo "     -s - Season (fall, spring, recurring)"
           echo "     -t – Target stage in docker file (base, r_lang, or r_julia)"
           echo "     -q – Whether to install SQLITE Kernel"; }

while getopts c:s:t:qh option; do
    case "${option}" in
        c) CLASS=${OPTARG};;
        s) SEASON=${OPTARG};;
        t) TARGET=${OPTARG};;
        q) SQLITE=true;;
        h) usage; exit;;
    esac
done

if [ "$SQLITE" != "true" ]; then
    SQLITE=false
fi

if ((OPTIND < 6))
then
    echo "Incomplete options specified. Make sure to pass at least the class name (-c) and target stage (-t)."
else
    export YEAR=$(date +'%Y')
    export CLASS=$CLASS
    export TARGET=$TARGET
    export SEASON=$SEASON
    export SQLITE=$SQLITE
    export GITHUB_SHA="\${GITHUB_SHA}"
    envsubst < ./templates/class_workflow.yml > ../.github/workflows/${CLASS}.yml &&
    envsubst < ./templates/class_tag.yml > ../.github/workflows/${CLASS}-${SEASON}-tag.yml &&
    mkdir ../requirements/classes/${CLASS}/ &&
    cat templates/requirements.txt >> ../requirements/classes/${CLASS}/requirements.txt  &&
    cat templates/requirements.jl >> ../requirements/classes/${CLASS}/requirements.jl  &&
    cat templates/requirements.pip.txt >> ../requirements/classes/${CLASS}/requirements.pip.txt  &&
    echo "Created workflow file at .github/workflows/${CLASS}.yml, .github/workflows/${CLASS}-${SEASON}-tag.yml and ./requirements/classes/${CLASS}/ directory with requirement files. "
fi
