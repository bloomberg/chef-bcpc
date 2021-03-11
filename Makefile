# -*- mode: Makefile -*-
# vim:list:listchars=tab\:>-:

export inventory = ansible/inventory.yml
export playbooks = ansible/playbooks
export ANSIBLE_CONFIG = ansible/ansible.cfg

headnodes = $$(ansible headnodes -i ${inventory} --list | tail -n +2 | wc -l)
rmqnodes = $$(ansible rmqnodes -i ${inventory} --list | tail -n +2 | wc -l)
storagenodes = \
        $$(ansible storagenodes -i ${inventory} --list | tail -n +2 | wc -l)
stubnodes = $$(ansible stubnodes -i ${inventory} --list | tail -n +2 | wc -l)

.NOTPARALLEL:
all : \
	sync-assets \
	configure-operator \
	configure-node \
	configure-chef-server \
	configure-chef-workstation \
	configure-chef-nodes \
	configure-web-server \
	configure-common-node \
	run-chef-client \
	reweight-ceph-osds \
	add-cloud-images \
	register-compute-nodes \
	enable-compute-service \
	configure-host-aggregates \
	print-success-banner

.PHONY: create destroy vtunnel vssh
create destroy vtunnel vssh:

	+$(MAKE) -C virtual $(filter $@,${MAKECMDGOALS})

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

configure-common-node :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/configure-common-node.yml \
		--limit cloud

run-chef-client : \
	run-chef-client-bootstraps \
	run-chef-client-rmqnodes \
	run-chef-client-headnodes \
	run-chef-client-worknodes \
	run-chef-client-storagenodes \
	run-chef-client-stubnodes

run-chef-client-bootstraps :

	ansible-playbook -v \
		-i ${inventory} ${playbooks}/site.yml \
		-t chef-client --limit bootstraps

run-chef-client-rmqnodes :

	@if [ "${rmqnodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/site.yml \
			-t chef-client --limit rmqnodes \
			-e "step=1"; \
		\
		if [ "${rmqnodes}" -gt 1 ]; then \
			ansible-playbook -v \
				-i ${inventory} ${playbooks}/site.yml \
				-t chef-client --limit rmqnodes \
				-e "step=1"; \
		fi \
	fi

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

run-chef-client-stubnodes :

	@if [ "${stubnodes}" -gt 0 ]; then \
		ansible-playbook -v \
			-i ${inventory} ${playbooks}/site.yml \
			-t chef-client --limit stubnodes; \
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
