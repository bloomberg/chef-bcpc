#!/bin/bash -x

set -ev

function main {
    find . -name "*.sh" -exec shellcheck {} \;
    find . -name "*.sh" -exec bashate -e E006 {} \;
    find . -name "*.py" -exec flake8 {} \;
    find ansible -name "*.yml" -exec ansible-lint -x 503 {} \;
    foodcritic chef/cookbooks
    cookstyle .
}

main
