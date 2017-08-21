Vagrant build guide
=====================
To get started with BCPC locally, we strongly recommend using the Vagrant mechanism. Vagrant is a tool that allows for easy provisioning of development environments that can be downloaded from [https://www.vagrantup.com](https://www.vagrantup.com).

Minimum Prerequisites
---------------------
* OS X or Linux
* Processor that supports VT-x virtualization extensions
* 16 GB of memory
* 100 GB of free disk space
* Vagrant 1.7 or better ([https://www.vagrantup.com](https://www.vagrantup.com))
* VirtualBox 4.3 or better (5.0+ recommended) ([https://www.virtualbox.org](https://www.virtualbox.org))
* Git, curl, rsync, ssh

On OS X, installing [Xcode](https://itunes.apple.com/us/app/xcode/id497799835?mt=12) from the Mac App Store and then installing Xcode's command-line tools from within Xcode will provide Git. On Linux, please consult documentation for your particular distribution to install any missing prerequisites via `apt-get`, `yum`, or another distribution-specific package manager.

Preparation
---
1. Ensure that you have all required tools installed (listed under **Minimum prerequisites**) and have adequate system resources.
2. Review `bootstrap/config/bootstrap_config.sh.defaults` and verify the sanity of the settings within. If you wish to make any changes, copy `bootstrap/config/bootstrap_config.sh.defaults` to `bootstrap/config/bootstrap_config.sh.overrides` and modify the overrides file.
3. If you are able to give more memory to the cluster VMs, doing so is strongly recommended (they will converge with 3GB but struggle).
4. If you need to use a proxy server to reach the Internet, set appropriate values for `BOOTSTRAP_HTTP_PROXY` and `BOOTSTRAP_HTTPS_PROXY` in the overrides file, adding the host:port for your proxy server.
5. If your HTTPS proxy performs man-in-the-middle rewriting of SSL connections, or you have some other need to augment the system root certificate stores of the VMs, additionally set `BOOTSTRAP_ADDITIONAL_CACERTS_DIR` to a directory on your computer where the necessary CA certificates can be found in individual PEM-encoded X.509 files, ending in the extension *.crt*. (Obviously put the certificates in that directory as well.)
6. Tweak any other configuration values you might want to, but the defaults should be reasonable for most people.
7. Edit `environments/Test-Laptop-Vagrant.json` as needed. If you plan on making modifications, it is recommended to make a copy of this environment file and update that instead (and remember to update the name of the environment referenced in `bootstrap_config.sh.overrides` if you do so).

Getting started
---------------
1. From the root of the chef-bcpc Git repository, change directory to `bootstrap/vagrant_scripts`.
2. Run `./BOOT_GO.sh`.
3. Watch the magic! (The build process usually takes 45-60 minutes to complete, depending on the speed of your computer and Internet connection.)
4. If you are re-cheffing for testing a PR for migration, make sure you run `vagrant provision` before running chef
   cookbooks
