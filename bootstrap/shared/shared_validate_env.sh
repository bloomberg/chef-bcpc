#!/bin/bash
required_bins=( curl git rsync ssh )

for binary in "${required_bins[@]}"; do
	if ! [ -x "$(command -v $binary)" ]; then
		printf "\n\nError: Necessary program '$binary' is not installed or available on your path.\nPlease fix by installing or correcting your PATH. Aborting now.\n\n" >&2
		exit 1
	fi
done

