#!/bin/bash

if [ -e "/root/keystonerc" ]; then
    source /root/keystonerc
fi

if [ -e "/usr/local/virtualenvs/masakari" ]; then masakari=/usr/local/virtualenvs/masakari/bin/masakari
elif [ -e "/usr/local/virtualenvs/masakariclient" ]; then masakari=/usr/local/virtualenvs/masakariclient/bin/masakari
elif [ -e "/usr/local/virtualenvs/masakarimonitor" ]; then masakari=/usr/local/virtualenvs/masakarimonitor/bin/masakari
else
    masakari=$(which masakari)
fi

if [ -z "$masakari" ] || [ -z "$(env | grep OS_AUTH_URL)" ]; then
    echo "Masakari client could not be found or authentication url not present!"
    exit 255
fi

segment=$1
host=$2
recovery_method=${3:-auto}
service_type=${3:-compute}

created=0

segment_uuid=$($masakari segment-list | grep $segment | awk '{print $2}')

# Check if segment already exists
if [ -z $segment_uuid ]; then
    $masakari segment-create --name $segment \
                            --description "Segment $segment" \
                            --recovery-method $recovery_method \
                            --service-type $service_type
    if [ "$?" -eq 0 ]; then
        echo "Created segment $segment"
        created=1
    else
        echo "Failed creating segment $segment"
        exit 1
    fi
fi

segment_uuid=$($masakari segment-list | grep $segment | awk '{print $2}')
if ! $masakari host-list --segment-id $segment_uuid | grep -q $host ; then
    $masakari host-create --segment-id $segment_uuid \
                          --name $host \
                          --type ipmi \
                          --control-attributes 'fake' \
                          --reserved False \
                          --on-maintenance False

    if [ "$?" -eq 0 ]; then
        echo "Created host $host"
        created=1
    else
        echo "Failed creating host $host in segment $segment with uuid $segment_uuid"
        exit 1
    fi
fi

if [ "$created" -eq 0 ]; then
    echo "Segment $segment and host $host already created"
fi
