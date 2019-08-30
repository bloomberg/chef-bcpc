#!/bin/bash -x

print_debug_info_osx () {
    printenv
    sysctl machdep.cpu
    kextstat
    sudo dmesg
    vm_stat
    df -h
    diskutil list
    ls -la
    groups
}

print_debug_info_linux () {
    printenv
    lscpu
    cat /proc/cpuinfo
    lsmod
    dmesg
    free -m
    df -h
    lsblk
    ls -la
    dpkg -l
    groups
}

upgrade_os_osx () {
    brew update
    brew upgrade
}

install_linters_osx () {
    brew install shellcheck ruby
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic cookstyle
}

upgrade_os_linux () {
    sudo apt update
    sudo apt -y upgrade
}

install_linters_linux () {
    sudo pip install bashate flake8 ansible-lint
    gem install foodcritic cookstyle
}

install_pytest () {
    sudo pip install testinfra
}

install_vagrant_osx () {
    sudo spctl --master-disable
    brew install qemu libvirt
    brew cask install vagrant
    sudo brew services start libvirt
    sudo ln -sf /usr/local/var/run/libvirt /var/run/libvirt
}

install_vagrant_linux () {
    vagrant_ver=2.2.5
    vagrant_deb="vagrant_${vagrant_ver}_x86_64.deb"
    wget "https://releases.hashicorp.com/vagrant/${vagrant_ver}/${vagrant_deb}"
    sudo dpkg -i ${vagrant_deb}
    sudo apt -y install libvirt-bin libvirt-dev dnsmasq qemu qemu-utils sshpass
    sudo systemctl restart libvirt-bin
}

install_vagrant_plugins () {
    vagrant plugin install vagrant-libvirt
    vagrant plugin install vagrant-mutate
    vagrant box add bento/ubuntu-18.04 --provider virtualbox
    vagrant mutate bento/ubuntu-18.04 libvirt
}

remove_dbs () {
    sudo /etc/init.d/mysql stop
    sudo /etc/init.d/postgresql stop
    sudo apt -y purge mongodb-org mongodb-org-mongos mongodb-org-server \
    mongodb-org-shell mongodb-org-tools \
    postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4 \
    postgresql-9.5 postgresql-client-9.5 postgresql-contrib-9.5 \
    postgresql-9.6 postgresql-client-9.6 postgresql-contrib-9.6 \
    postgresql-client postgresql-client-common \
    mysql-server-5.7 mysql-server-core-5.7 mysql-client-5.7
}

print_debug_info_"${TRAVIS_OS_NAME}"

if [ "${TRAVIS_OS_NAME}" == "osx" ] ; then
    sudo pip2 install -U pip setuptools
    CONFIGURE_ARGS="with-libvirt-include=/usr/local/include/libvirt"
    CONFIGURE_ARGS="${CONFIGURE_ARGS} with-libvirt-lib=/usr/local/lib"
fi

if [ "${1}" == "linter" ] ; then
    install_linters_"${TRAVIS_OS_NAME}"
elif [ "${1}" == "build" ] ; then
    if [ "${TRAVIS_OS_NAME}" == "linux" ] ; then
        remove_dbs
    fi
    upgrade_os_"${TRAVIS_OS_NAME}"
    install_vagrant_"${TRAVIS_OS_NAME}"
    install_vagrant_plugins
    install_pytest
fi
