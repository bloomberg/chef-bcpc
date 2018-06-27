# Project Title

One Paragraph of project description goes here

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

What things you need to install the software and how to install them

```
Give examples
```

### Installing

A step by step series of examples that tell you have to get a development env running

Say what the step will be

```
Give the example
```

And repeat

```
until finished
```

End with an example of getting some data out of the system or using it for a little demo

## Running the tests

Explain how to run the automated tests for this system

### Break down into end to end tests

Explain what these tests test and why

```
Give an example
```

### And coding style tests

Explain what these tests test and why

```
Give an example
```

## Deployment

Add additional notes about how to deploy this on a live system

## Built With

* [Dropwizard](http://www.dropwizard.io/1.0.2/docs/) - The web framework used
* [Maven](https://maven.apache.org/) - Dependency Management
* [ROME](https://rometools.github.io/rome/) - Used to generate RSS Feeds

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

BCC is built using the following open-source software:

 - [Apache HTTP Server](http://httpd.apache.org/)
 - [Ceph](http://ceph.com/)
 - [Chef](http://www.opscode.com/chef/)
 - [HAProxy](http://haproxy.1wt.eu/)
 - [Memcached](http://memcached.org)
 - [OpenStack](http://www.openstack.org/)
 - [Percona XtraDB Cluster](http://www.percona.com/software/percona-xtradb-cluster)
 - [PowerDNS](https://www.powerdns.com/)
 - [RabbitMQ](http://www.rabbitmq.com/)
 - [Ubuntu](http://www.ubuntu.com/)
 - [Vagrant](http://www.vagrantup.com/) - 2.0.0 or better recommended
 - [VirtualBox](https://www.virtualbox.org/) - 5.2.0 or better recommended

Thanks to all of these communities for producing this software!

Overview
========
This is a set of [Chef](https://github.com/opscode/chef) cookbooks to bring up
an instance of an [OpenStack](http://www.openstack.org/)-based cluster of head
and worker nodes.  In addition to hosting virtual machines, there are a number
of additional services provided with these cookbooks - such as distributed
storage, DNS, log aggregation/search, and monitoring - see below for a partial
list of services provided by these cookbooks.

Each head node runs all of the core services in a highly-available manner with
no restriction upon how many head nodes there are.  The cluster is deemed
operational as long as 50%+1 of the head nodes are online.  Otherwise, a
network partition may occur with a split-brain scenario.  In practice,
we currently recommend roughly one head node per rack.

Each worker node runs the relevant services (nova-compute, Ceph OSDs, etc.).
There is no limitation on the number of worker nodes.  In practice, we
currently recommend that the cluster should not grow to more than 200 worker
nodes.

Setup
=====
To get going in a hurry, we recommend the Vagrant mechanism for building your cluster. Please read the [Vagrant Bootstrap Guide](https://github.com/bloomberg/chef-bcpc/blob/master/docs/vagrant_build_guide.md) for information on getting BCPC set up locally with Vagrant.

If you are interested in building your cluster the hard way without Vagrant, there are Ansible scripts in `bootstrap/ansible_scripts` for creating a hardware cluster that can be applied to a virtualized cluster (manual work will be required). The Ansible scripts are documented at [Using Ansible (hardware build)](https://github.com/bloomberg/chef-bcpc/blob/master/docs/ansible_hardware_build_guide.md) and [Using Ansible (local build)](https://github.com/bloomberg/chef-bcpc/blob/master/docs/ansible_local_build_guide.md).
