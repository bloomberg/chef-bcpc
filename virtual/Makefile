create : create-virtual-network create-virtual-hosts
destroy : destroy-virtual-network destroy-virtual-hosts

create-virtual-hosts :

	bin/create-virtual-environment.sh

create-virtual-network :

	bin/create-virtual-network.sh

destroy-virtual-hosts :

	bin/destroy-virtual-environment.sh

destroy-virtual-network :

	bin/destroy-virtual-network.sh

###############################################################################
# virtual environment helper targets
###############################################################################

vtunnel:

	ssh_tunnel_conf=/tmp/ssh-config.$$$$ ;\
	vagrant ssh-config r1n0 > $${ssh_tunnel_conf} ;\
	ssh -f -N -F $${ssh_tunnel_conf} -L *:8443:10.65.0.254:443 -L *:6080:10.65.0.254:6080 r1n0 ;\
	rm $${ssh_tunnel_conf} ;\
	echo "\nOpenStack Dashboard available at: https://127.0.0.1:8443/horizon/\n"

host ?= r1n1
vssh:

	vagrant ssh $(host) -c 'sudo -i'
