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
    sudo apt-get install -y shellcheck
    for pkg in bashate flake8 ansible-lint==5.3.2; do
        pipx install --force "${pkg}"
    done
    pipx inject ansible-lint ansible==5.2.0
    sudo gem install cookstyle
}

main
