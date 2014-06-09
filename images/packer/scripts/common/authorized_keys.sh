#!/bin/bash

mkdir -p .ssh
cat id_rsa.pub >> .ssh/authorized_keys
chown -R ubuntu:ubuntu .ssh
