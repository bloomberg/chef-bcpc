#!/bin/bash -x

function main {
    install_linters_linux
}

#
# GithubActions Runners have pipx[1] installed.
# pipx is a CLI-specific tool where each application runs in its own venv.
# For `ansible-lint`, this implies the need to inject ansible into its venv.
#
# [1]: https://github.com/pypa/pipx
#

function install_linters_linux {
    echo "${PWD}"
    env
    python3 -m venv linter_venv
    cd linter_venv && . bin/activate

    sudo apt-get install -y shellcheck
    for pkg in bashate flake8 ansible-lint ansible; do
        pip install --force "${pkg}"
    done

    sudo gem install cookstyle
}

main
