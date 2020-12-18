# chef

[Chef](https://docs.chef.io/) automation is used to install Openstack and
various supporting services on the cluster specified in the ansible inventory
file.

## attributes

The `attributes` directory contains defaults for variables used in chef
[recipes](#recipes), [templates](#templates), and [libraries](#libraries). See
the [readme](../../../ansible/README.md) in the ansible directory for
information on how to override these values.

## files

Files used during the configuration of services by chef go here. Examples
include release keys for the repo from which we retrieved a particular package
and unchanging configuration files.

## libraries

This directory contains common definitions used across multiple chef recipes.

## recipes

Contains the chef recipes that stand up Openstack and supporting services.

## templates

Contains files whose contents are dynamically manipulated by chef recipes. An
example would be a service's configuration file, which chef modifies according
to the appropriate recipe and corresponding attributes.
