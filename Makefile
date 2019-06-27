# -*- mode: Makefile -*-
# vim:list:listchars=tab\:>-:

export inventory = ansible/inventory.yml
export playbooks = ansible/playbooks
export ANSIBLE_CONFIG = ansible/ansible.cfg

headnodes = $$(ansible headnodes -i ${inventory} --list | tail -n +2 | wc -l)
storagenodes = \
        $$(ansible storagenodes -i ${inventory} --list | tail -n +2 | wc -l)

all : \
	sync-assets \
	configure-operator \
	configure-apt \
	configure-networking \
	configure-chef-server \
	configure-chef-workstation \
	configure-chef-nodes \
	configure-file-server \
	run-chef-client \
	add-cloud-images \
	register-compute-nodes

create: create-virtual-network create-virtual-hosts

destroy: destroy-virtual-hosts destroy-virtual-network

create-virtual-hosts :

	virtual/bin/create-virtual-environment.sh

create-virtual-network :

	virtual/bin/create-virtual-network.sh

destroy-virtual-hosts :

	virtual/bin/destroy-virtual-environment.sh

destroy-virtual-network :

	virtual/bin/destroy-virtual-network.sh

configure-operator :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t operator --limit cloud

configure-apt :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t configure-apt --limit cloud

configure-networking :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t configure-networking --limit cloud

sync-assets :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t sync-assets --limit localhost

configure-chef-server :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-server --limit bootstraps

configure-chef-workstation :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-workstation --limit bootstraps

configure-chef-nodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-node --limit cloud

run-chef-client : \
	run-chef-client-bootstraps \
	run-chef-client-headnodes \
	run-chef-client-worknodes \
	run-chef-client-storagenodes

run-chef-client-bootstraps :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit bootstraps

run-chef-client-headnodes :

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

run-chef-client-worknodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit worknodes

run-chef-client-storagenodes :

	@if [ "${storagenodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/site.yml \
			-t chef-client --limit storagenodes; \
	fi

add-cloud-images:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t add-cloud-images --limit headnodes

register-compute-nodes:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t register-compute-nodes --limit headnodes

sync-chef :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t sync-chef --limit bootstraps

upload-all :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t upload-extra-cookbooks --limit bootstraps

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t upload-bcpc --limit bootstraps

configure-file-server :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t file-server --limit bootstraps

configure-host-aggregates :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-host-aggregates --limit headnodes

###############################################################################
# helper targets
###############################################################################

generate-chef-environment :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t generate-chef-environment --limit bootstraps

adjust-ceph-pool-pgs:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t adjust-ceph-pool-pgs --limit headnodes

ceph-destroy-osds:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t ceph-destroy-osds \
		-e "destroy_osds=$(destroy_osds)" \
		--limit storagenodes
