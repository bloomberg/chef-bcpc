#!/bin/bash

sed -r -i -e '/^Defaults[[:space:]]+env_reset/a Defaults\texempt_group=sudo' \
    -e 's/^%sudo[[:space:]]+ALL=(ALL:ALL) ALL/%sudo\tALL=NOPASSWD:ALL/' /etc/sudoers
