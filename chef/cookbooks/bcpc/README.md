# chef

[Chef](https://docs.chef.io/) automation is used to install OpenStack and
various supporting services on the cluster specified in the Ansible inventory
file.

## attributes

The `attributes` directory contains defaults for variables used in Chef
[recipes](#recipes), [templates](#templates), and [libraries](#libraries). See
the [readme](../../../ansible/README.md) in the ansible directory for
information on how to override these values.

## files

Files used during the configuration of services by Chef go here. Examples
include release keys for the repo from which we retrieved a particular package
and unchanging configuration files.

## libraries

This directory contains common definitions used across multiple Chef recipes.

## recipes

Contains the Chef recipes that stand up OpenStack and supporting services.

## templates

Contains files whose contents are dynamically manipulated by Chef recipes. An
example would be a service's configuration file, which Chef modifies according
to the appropriate recipe and corresponding attributes.
