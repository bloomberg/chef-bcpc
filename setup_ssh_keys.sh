#!/bin/bash

if [[ ! -f $HOME/.ssh/authorized_keys ]]; then
  if [[ ! -d $HOME/.ssh ]]; then
    mkdir $HOME/.ssh
  fi
  cp $1 $HOME/.ssh/authorized_keys
fi
