# allows make to accept spaces over tabs
#
.RECIPEPREFIX +=

export inventory = virtual/ansible/inventory
export ANSIBLE_CONFIG = ansible/ansible.cfg

all : \
  download-assets \
  operator \
  chef-server \
  chef-workstation \
  chef-node \
  file-server \
  chef-client

create :

  ansible-playbook -i ${inventory} virtual/ansible/site.yml -t create

destroy :

  ansible-playbook -i ${inventory} virtual/ansible/site.yml -t destroy

operator :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t operator

download-assets :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t download-assets

chef-server :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t chef-server

chef-workstation :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t chef-workstation

chef-node :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t chef-node

chef-client :

  ansible-playbook -v \
    -i ${inventory} ansible/site.yml \
    -t chef-client --limit bootstraps

  ansible-playbook -v \
    -i ${inventory} ansible/site.yml \
    -t chef-client --limit headnodes \
    -e "step=1"


  ansible-playbook -v \
    -i ${inventory} ansible/site.yml \
    -t chef-client --limit headnodes \
    -e "step=1"

  ansible-playbook -v \
    -i ${inventory} ansible/site.yml \
    -t chef-client --limit worknodes

upload-bcpc :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t upload-bcpc

upload-all :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t upload-extra-cookbooks

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t upload-bcpc

file-server :

  ansible-playbook \
    -i ${inventory} ansible/site.yml \
    -t file-server
