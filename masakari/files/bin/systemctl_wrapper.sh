#!/bin/bash

action=$1
service=$2

if [ -e /bin/systemctl ]; then
  /bin/systemctl $action $service
elif [ -e /usr/bin/service ]; then
  /usr/bin/service $service $action
else
  /usr/sbin/service $service $action
fi

