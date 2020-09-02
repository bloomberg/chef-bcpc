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
	configure-node \
	configure-chef-server \
	configure-chef-workstation \
	configure-chef-nodes \
	configure-web-server \
	run-chef-client \
	reweight-ceph-osds \
	add-cloud-images \
	register-compute-nodes \
	enable-compute-service \
	configure-host-aggregates

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

generate-chef-databags :

	virtual/bin/generate-chef-databags.py -s

configure-operator :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t configure-operator --limit cloud

configure-node :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t configure-node --limit cloud

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

reweight-ceph-osds:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t reweight-ceph-osds --limit headnodes

add-cloud-images:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t add-cloud-images --limit headnodes

enable-compute-service:

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t enable-compute-service --limit headnodes

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

configure-web-server :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t web-server --limit bootstraps

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

###############################################################################
# virtual environment helper targets
###############################################################################

vtunnel:

	cd virtual ;\
	ssh_tunnel_conf=/tmp/ssh-config.$$$$ ;\
	vagrant ssh-config r1n0 > $${ssh_tunnel_conf} ;\
	ssh -f -N -F $${ssh_tunnel_conf} -L *:8443:10.65.0.254:443 -L *:6080:10.65.0.254:6080 r1n0 ;\
	rm $${ssh_tunnel_conf} ;\
	echo "\nOpenStack Dashboard available at: https://127.0.0.1:8443/horizon/\n"

host ?= r1n1
vssh:

	cd virtual; vagrant ssh $(host) -c 'sudo -i'
