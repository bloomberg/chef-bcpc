#!/bin/bash -x

function main {
    install_linters_linux
}

function install_linters_linux {
    sudo apt-get install -y shellcheck
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic cookstyle
}

main
