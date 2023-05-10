# -*- mode: Makefile -*-
# vim:list:listchars=tab\:>-:

export inventory = ansible/inventory.yml
export playbooks = ansible/playbooks
export ANSIBLE_CONFIG = ansible/ansible.cfg

auxnodes = $$(ansible auxnodes -i ${inventory} --list | tail -n +2 | wc -l)
headnodes = $$(ansible headnodes -i ${inventory} --list | tail -n +2 | wc -l)
storagenodes = \
	$$(ansible storagenodes -i ${inventory} --list | tail -n +2 | wc -l)
stubnodes = $$(ansible stubnodes -i ${inventory} --list | tail -n +2 | wc -l)

all : \
	sync-assets \
	configure-operator \
	configure-node \
	configure-chef-server \
	configure-chef-workstation \
	configure-chef-nodes \
	configure-web-server \
	configure-common-node \
	configure-haproxy \
	configure-haproxy-clients \
	run-chef-client \
	configure-ceph \
	add-cloud-images \
	register-compute-nodes \
	enable-compute-service \
	configure-host-aggregates \
	configure-licenses \
	print-success-banner

create: create-virtual-network create-virtual-hosts

destroy: destroy-virtual-hosts destroy-virtual-network

upload-packer-box :

	virtual/packer/bin/upload-packer-box.sh

download-packer-box :

	virtual/packer/bin/download-packer-box.sh

create-packer-box :

	virtual/packer/bin/create-packer-box.sh

destroy-packer-box :

	virtual/packer/bin/destroy-packer-box.sh

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
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t chef-server --limit bootstraps

configure-chef-workstation :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t chef-workstation --limit bootstraps

configure-chef-nodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-node --limit cloud

configure-common-node :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/configure-common-node.yml \
		--limit cloud

configure-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-haproxy -f 1 --limit headnodes

configure-haproxy-clients : \
	configure-keystone-haproxy \
	configure-glance-haproxy \
	configure-neutron-haproxy \
	configure-placement-haproxy \
	configure-nova-haproxy \
	configure-cinder-haproxy \
	configure-heat-haproxy \
	configure-watcher-haproxy

configure-keystone-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-keystone-haproxy -f 1 --limit headnodes

configure-glance-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-glance-haproxy -f 1 --limit headnodes

configure-neutron-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-neutron-haproxy -f 1 --limit headnodes

configure-placement-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-placement-haproxy -f 1 --limit headnodes

configure-nova-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-nova-haproxy -f 1 --limit headnodes

configure-cinder-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-cinder-haproxy -f 1 --limit headnodes

configure-heat-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-heat-haproxy -f 1 --limit headnodes

configure-watcher-haproxy :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-watcher-haproxy -f 1 --limit headnodes

run-chef-client : \
	run-chef-client-bootstraps \
	run-chef-client-auxnodes \
	run-chef-client-headnodes \
	run-chef-client-worknodes \
	run-chef-client-storagenodes \
	run-chef-client-stubnodes

run-chef-client-bootstraps :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t chef-client --limit bootstraps

run-chef-client-auxnodes :

	@if [ "${auxnodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/site.yml \
			-t chef-client --limit auxnodes \
			-e "step=1"; \
		\
		if [ "${auxnodes}" -gt 1 ]; then \
			ansible-playbook -v \
				-i ${inventory} ${playbooks}/site.yml \
				-t chef-client --limit auxnodes \
				-e "step=1"; \
		fi \
	fi

run-chef-client-headnodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t chef-client --limit headnodes \
		-e "step=1"

	@if [ "${headnodes}" -gt 1 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/headnodes.yml \
			-t chef-client --limit headnodes \
			-e "step=1"; \
	fi

run-chef-client-worknodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/worknodes.yml \
		-t chef-client --limit worknodes

run-chef-client-storagenodes :

	@if [ "${storagenodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/storagenodes.yml \
			-t chef-client --limit storagenodes; \
	fi

run-chef-client-stubnodes :

	@if [ "${stubnodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/stubnodes.yml \
			-t chef-client --limit stubnodes; \
	fi

configure-ceph :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/storageheadnodes.yml \
		-t configure-ceph --limit storageheadnodes

add-cloud-images :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t add-cloud-images --limit headnodes

enable-compute-service :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t enable-compute-service --limit headnodes

register-compute-nodes :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t register-compute-nodes --limit headnodes

sync-chef :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t sync-chef --limit bootstraps

upload-all :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t upload-extra-cookbooks --limit bootstraps

configure-web-server :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t web-server --limit bootstraps

configure-host-aggregates :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-host-aggregates --limit headnodes

configure-licenses :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/headnodes.yml \
		-t configure-licenses --limit headnodes

define SUCCESS_BANNER
                _
              (`  ).                   _
             (     ).              .:(`  )`.
)           _(       '`.          :(   .    )
        .=(`(      .   )     .--  `.  (    ) )
       ((    (..__.:'-'   .+(   )   ` _`  ) )
`.     `(       ) )       (   .  )     (   )  ._
  )      ` __.:'   )     (   (   ))     `-'.-(`  )
)  )  ( )       --'       `- __.'         :(      ))
.-'  (_.'          .')                    `(    )  ))
                  (_  )                     ` __.:'

--..,___.--,--'`,---..-.--+--.,,-,,..._.--..-._.-a:f--.
  ^^^^^^^^^^^^^^^^^^^^^
  It's getting cloudy
endef

export SUCCESS_BANNER

print-success-banner :

	@echo "$$SUCCESS_BANNER"

###############################################################################
# helper targets
###############################################################################

generate-chef-environment :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/bootstraps.yml \
		-t generate-chef-environment --limit bootstraps

adjust-ceph-pool-pgs :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/storageheadnoes.yml \
		-t adjust-ceph-pool-pgs --limit storageheadnodes

ceph-destroy-osds :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/storagenodes.yml \
		-t ceph-destroy-osds \
		-e "destroy_osds=$(destroy_osds)" \
		--limit storagenodes

###############################################################################
# virtual environment helper targets
###############################################################################

vtunnel :

	cd virtual ;\
	ssh_tunnel_conf=/tmp/ssh-config.$$$$ ;\
	vagrant ssh-config r1n0 > $${ssh_tunnel_conf} ;\
	ssh -f -N -F $${ssh_tunnel_conf} -L *:8443:10.65.0.254:443 -L *:6080:10.65.0.254:6080 r1n0 ;\
	rm $${ssh_tunnel_conf} ;\
	echo "\nOpenStack Dashboard available at: https://127.0.0.1:8443/horizon/\n"

host ?= r1n1
vssh :

	cd virtual; vagrant ssh $(host) -c 'sudo -i'
