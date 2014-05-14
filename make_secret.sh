#!/bin/bash

if [ ! -f secret_file ]; then
    echo " ** creating random encryption file in ./secret_file"
    touch secret_file
    chmod 600 secret_file
    openssl rand -base64 512 | tr -d '\r\n' >> secret_file
else
    echo " ** ./secret_file already exists"
fi
