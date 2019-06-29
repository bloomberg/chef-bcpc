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
    brew install shellcheck ruby
    sudo pip2 install -U pip setuptools
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic cookstyle
    git clone https://github.com/russell/git-lint-diff.git
}

upgrade_os_linux () {
    sudo apt-get update
    sudo aptitude -y full-upgrade
}

install_linters_linux () {
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic cookstyle
    git clone https://github.com/russell/git-lint-diff.git
}

install_pytest () {
    sudo pip install testinfra
}

install_vagrant_osx () {
    sudo spctl --master-disable
    brew cask install vagrant
}

install_vagrant_linux () {
    vagrant_ver=2.2.5
    vagrant_deb="vagrant_${vagrant_ver}_x86_64.deb"
    wget "https://releases.hashicorp.com/vagrant/${vagrant_ver}/${vagrant_deb}"
    sudo dpkg -i ${vagrant_deb}
    sudo apt-get -y install libopus0 libsdl1.2debian libcaca0
    vb_ver=6.0.8
    vb_build=130520
    vb_v=${vb_ver:0:3}
    vb_deb="virtualbox-${vb_v}_${vb_ver}-${vb_build}~Ubuntu~xenial_amd64.deb"
    wget "http://download.virtualbox.org/virtualbox/${vb_ver}/${vb_deb}"
    sudo dpkg -i ${vb_deb}
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
install_pytest
install_vagrant_"${TRAVIS_OS_NAME}"
