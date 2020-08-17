#!/bin/bash
set -e

usage () { echo "Usage:"
           echo "     -h – help"
           echo "     -c – Class name"
           echo "     -s - Season (fall, spring, recurring)"
           echo "     -t – Target stage in docker file (base, r_lang, or r_julia)"
           echo "     -m – Whether to install MySQL"; }

while getopts c:s:t:ms:h option; do
    case "${option}" in
        c) CLASS=${OPTARG};;
        s  SEASON=${OPTARG};;
        t) TARGET=${OPTARG};;
        m) WITH_MYSQL=true;;
        h) usage; exit;;
    esac
done

if [ "$WITH_MYSQL" != "true" ]; then
    WITH_MYSQL=false
fi

if ((OPTIND < 6))
then
    echo "Incomplete options specified. Make sure to pass at least the class name (-c) and target stage (-t)."
else
    (envsubst '${CLASS} ${TARGET}' < ./templates/class_workflow.yml) > ../.github/workflows/${CLASS}.yml &&
    (envsubst '${CLASS} ${TARGET}' < ./templates/class_tag.yml) > ../.github/workflows/${CLASS}-${SEASON}-tag.yml &&
    mkdir ../requirements/classes/${CLASS}/ &&
    cd ../requirements/classes/${CLASS}/ &&
    touch requirements.txt  &&
    touch requirement.jl  &&
    touch requirements.pip.txt  &&
    echo "Created workflow file at .github/workflows/${CLASS}.yml, .github/workflows/${CLASS}-${SEASON}-tag.yml and /requirements/classes/${CLASS}/ directory with requirement files. "

fi
