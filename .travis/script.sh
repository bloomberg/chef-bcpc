#!/bin/bash -x

set -ev

if [ "${1}" == "linter" ] ; then
    find . -name "*.sh" -print0 | xargs -0 -n1 shellcheck
    find . -name "*.sh" -print0 | xargs -0 -n1 bashate -e E006
    find . -name "*.py" -print0 | xargs -0 -n1 flake8
    find ansible -name "*.yml" -print0 | xargs -0 -n1 ansible-lint -x 503
    foodcritic chef/cookbooks
    cookstyle .
elif [ "${1}" == "build" ] ; then
    :  #pytest
fi
