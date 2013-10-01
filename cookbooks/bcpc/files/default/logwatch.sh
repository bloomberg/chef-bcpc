#!/bin/bash

CODE=`printf '\033'`

for i in keystone glance cinder nova quantum; do 
    tail -F /var/log/$i/*.log | sed -e "s/\([0-9]*-[0-9]*-[0-9]* [0-9]*:[0-9]*:[0-9]*\)[ ]*\([0-9]*\)\?[ ]*\(DEBUG\|AUDIT\|INFO\)\?\([A-Z]*\)[ ]*\(\[\?[a-zA-Z0-9_.]*\]\?\)[ ]*\(.*\)/$CODE[0;36m\1$CODE[0m $CODE[0;32m\3$CODE[0m$CODE[1;31m\4$CODE[0m $CODE[0;33m\5$CODE[0m $CODE[0;37m\6$CODE[0m/" &
done
