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
    python3 -m venv /tmp/linter_venv
    cd /tmp/linter_venv && . bin/activate

    sudo apt-get install -y shellcheck
    pip install --force bashate flake8 ansible-lint ansible

    sudo gem install cookstyle
}

main
