# -*- mode: Makefile -*-
# vim:list:listchars=tab\:>-:

export inventory = ansible/inventory
export playbooks = ansible/playbooks
export ANSIBLE_CONFIG = ansible/ansible.cfg

headnodes = $$(ansible headnodes -i ${inventory} --list | tail -n +2 | wc -l)

all : \
	download-assets \
	operator \
	chef-server \
	chef-workstation \
	chef-node \
	file-server \
	chef-client \
	adjust-ceph-pool-pgs \
	add-cloud-images \
	register-compute-nodes

create :

	virtual/bin/create-virtual-environment.sh

destroy :

	virtual/bin/destroy-virtual-environment.sh

operator :

	ansible-playbook -v -i ${inventory} ${playbooks}/site.yml -t operator

download-assets :

	ansible-playbook -v -i ${inventory} ${playbooks}/site.yml -t download-assets

chef-server :

	ansible-playbook -v -i ${inventory} ${playbooks}/site.yml -t chef-server

chef-workstation :

	ansible-playbook -v -i ${inventory} ${playbooks}/site.yml -t chef-workstation

chef-node :

	ansible-playbook -v -i ${inventory} ${playbooks}/site.yml -t chef-node

chef-client : \
	chef-client-bootstraps \
	chef-client-headnodes \
	chef-client-worknodes

chef-client-bootstraps :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit bootstraps

chef-client-headnodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit headnodes \
		-e "step=1"

	@if [ "${headnodes}" -gt 1 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/site.yml \
			-t chef-client --limit headnodes \
			-e "step=1"; \
	fi

chef-client-worknodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit worknodes

adjust-ceph-pool-pgs:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t adjust-ceph-pool-pgs --limit headnodes

add-cloud-images:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t add-cloud-images --limit headnodes

register-compute-nodes:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t register-compute-nodes --limit headnodes

upload-bcpc :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t upload-bcpc

upload-all :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t upload-extra-cookbooks

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t upload-bcpc

file-server :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t file-server

###############################################################################
# helper targets
###############################################################################

generate-chef-roles :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t generate-chef-roles

