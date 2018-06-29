#!/bin/bash

TIMEOUT=60
START=$(date +%s)
ENDPOINT=$1

if [[ -z $1 ]]; then
        echo "You must provide an endpoint to test." >&2
        exit 2
fi

# run in a loop instead of using curl's built-in retry because
# we want to retry repeatedly even if nothing is listening
# (curl will exit immediately)
until curl -s $ENDPOINT >/dev/null 2>&1; do
        if [[ $(($(date +s) - $START)) -gt $TIMEOUT ]]; then
                exit 1
        fi
        sleep 1
done
