# -*- mode: Makefile -*-
# vim:list:listchars=tab\:>-:

export inventory = ansible/inventory
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

	virtual/bin/create-virtual-environment

destroy :

	virtual/bin/destroy-virtual-environment

operator :

	ansible-playbook -v -i ${inventory} ansible/site.yml -t operator

download-assets :

	ansible-playbook -v -i ${inventory} ansible/site.yml -t download-assets

chef-server :

	ansible-playbook -v -i ${inventory} ansible/site.yml -t chef-server

chef-workstation :

	ansible-playbook -v -i ${inventory} ansible/site.yml -t chef-workstation

chef-node :

	ansible-playbook -v -i ${inventory} ansible/site.yml -t chef-node

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

	ansible-playbook -v \
		-i ${inventory} ansible/site.yml \
		-t upload-bcpc

upload-all :

	ansible-playbook -v \
		-i ${inventory} ansible/site.yml \
		-t upload-extra-cookbooks

	ansible-playbook -v \
		-i ${inventory} ansible/site.yml \
		-t upload-bcpc

file-server :

	ansible-playbook -v \
		-i ${inventory} ansible/site.yml \
		-t file-server
