#!/bin/bash -x

set -e

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
    source /tmp/linter_venv/bin/activate

    sudo apt-get install -y shellcheck
    pip install -U setuptools wheel pip
    pip install -I --force \
        bashate==2.1.0 \
        flake8==4.0.1 \
        ansible-lint==5.4.0 \
        ansible==5.4.0

    sudo gem install cookstyle
}

main
