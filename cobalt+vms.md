VMS+Cobalt
==========

Setup
-----

1. Setup the `vms_key`.

 * If you haven't bootstrapped your environment yet, you can add the
   VMS key via `environments/Test-Laptop.json`. Under `bcpc` create a
   key `vms_key` and fill it in with your download key.

 * If you already have your environment, on the bootstrap node run:
   ```
   knife environment edit Test-Laptop
   ```
   And add `vms_key` under `bcpc` with your download key.

2. Re-run chef-client on all nodes.

Usage
-----

1. Install the cobaltclient extensions.

 * Via the apt repositories:
   ```
   # Install Gridcentric signing key
   wget -O - http://downloads.gridcentric.com/packages/gridcentric.key | sudo apt-key add -
 
   # Add Gridcentric repositories
   echo deb http://downloads.gridcentric.com/packages/cobaltclient/grizzly/ubuntu/ gridcentric multiverse | sudo tee -a /etc/apt/sources.list.d/cobaltclient.list
  
   # Update apt
   sudo apt-get update
   
   # Install the novaclient plugin for all users
   sudo apt-get install -y cobalt-novaclient
   ```

 * Or via pip:
   ```
   # Install the novaclient plugin for the current user
   pip install --user cobalt_python_novaclient_ext
   ```

2. Install a suitable image.

There are a few issues with the CirrOS image.

You can easily add an Ubuntu 12.04 image as follows:
   ```
   curl -O http://cloud-images.ubuntu.com/releases/precise/release/ubuntu-12.04-server-cloudimg-amd64-disk1.img
   qemu-img convert -O raw ubuntu-12.04-server-cloudimg-amd64-disk1.img ubuntu-12.04-server-cloudimg-amd64-disk1.raw
   glance image-create --name=ubuntu-12.04 --is-public=True --container-format=bare --disk-format=raw --file ubuntu-12.04-server-cloudimg-amd64-disk1.raw
   ```

3. Use it.

 Example usage:
   ```
   # Generate a keypair for instances.
   ssh-keygen
   nova keypair-add ubuntu --pub_key=~/.ssh/id_rsa.pub

   # Boot a new instance the old-fashioned way.
   nova boot --key_name ubuntu --image ubuntu-12.04 --flavor 1 --availability_zone=Test-Laptop instance-name

   # Install the agent in the instance (for IP reconfig, etc.).
   nova cobalt-install-agent --user ubuntu instance-name

   # Create a new live image.
   nova live-image-create instance-name live-image-name

   # Launch a clone.
   nova live-image-start --live-image live-image-name new-instance-name
   ```
