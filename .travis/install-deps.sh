#!/bin/bash -x

print_debug_info () {
    printenv
    lscpu
    cat /proc/cpuinfo
    lsmod
    dmesg
    free -m
    df -h
    lsblk
    ls -la
}

upgrade_os_osx () {
    brew update
    brew upgrade
}

install_linters_osx () {
    brew install shellcheck ruby23
    sudo pip2 install -U pip setuptools
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic
    git clone https://github.com/russell/git-lint-diff.git
}

upgrade_os_linux () {
    sudo apt-get update
    sudo aptitude -y full-upgrade
}

install_linters_linux () {
    shellcheck_deb='shellcheck_0.4.7-1_amd64.deb'
    sudo pip install bashate flake8 ansible-lint
    gem install rubocop
    gem install foodcritic
    wget http://ftp.debian.org/debian/pool/main/s/shellcheck/${shellcheck_deb}
    sudo dpkg -i ${shellcheck_deb}
    git clone https://github.com/russell/git-lint-diff.git
}

remove_dbs () {
    sudo /etc/init.d/mysql stop
    sudo /etc/init.d/postgresql stop
    sudo apt-get purge mongodb-org mongodb-org-mongos mongodb-org-server \
    mongodb-org-shell mongodb-org-tools postgresql-9.2 postgresql-9.3 \
    postgresql-9.4 postgresql-9.5 postgresql-9.6 postgresql-client \
    postgresql-client-9.2 postgresql-client-9.3 postgresql-client-9.4 \
    postgresql-client-9.5 postgresql-client-9.6 postgresql-client-common \
    postgresql-common postgresql-contrib-9.2 postgresql-contrib-9.3 \
    postgresql-contrib-9.4 postgresql-contrib-9.5 postgresql-contrib-9.6 \
    mysql-server-5.6 mysql-server-core-5.6 rabbitmq-server
}

if [ "${TRAVIS_OS_NAME}" == "osx" ] ; then
    :
fi

if [ "${TRAVIS_OS_NAME}" == "linux" ] ; then
    remove_dbs
fi

upgrade_os_"${TRAVIS_OS_NAME}"
install_linters_"${TRAVIS_OS_NAME}"
