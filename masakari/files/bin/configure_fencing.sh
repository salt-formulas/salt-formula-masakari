#!/bin/bash

# Check if corosync is up
last_result=1
for i in $(seq 1 10); do
  cibadmin --query -o resource >/dev/null 2>&1
  last_result=$?
  [ "$last_result" -eq "0" ] && break;
  echo "Corosync not yet up, sleeping $i secs";
  sleep $i;
done

if [ "$last_result" -ne "0" ]; then
  echo "corosync not yet up!"
  exit
fi

hostname=$(hostname)

if cibadmin --query -o resource | grep st-$hostname >/dev/null; then
  echo "Resource already exists in corosync. "
  exit;
fi

ipmi_ip=$(/usr/bin/ipmitool lan print | grep Address | grep '\.' | awk '{print $4}')
password=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-8})

/usr/bin/ipmitool user set name 4 fencing
/usr/bin/ipmitool user set password 4 $password
/usr/bin/ipmitool channel setaccess 1 4 link=on ipmi=on callin=on privilege=3
/usr/bin/ipmitool user enable 4


cat > /tmp/fencing.xml << EOF
<primitive id="st-$hostname" class="stonith" type="external/ipmi" >
  <instance_attributes id="st-$hostname-params" >
    <nvpair id="st-$hostname-hostname" name="hostname" value="$hostname" />
    <nvpair id="st-$hostname-ipaddr" name="ipaddr" value="$ipmi_ip" />
    <nvpair id="st-$hostname-login" name="userid" value="fencing" />
    <nvpair id="st-$hostname-passwd" name="passwd" value="$password" />
    <nvpair id="st-$hostname-interface" name="interface" value="lanplus" />
    <nvpair id="st-$hostname-priv" name="priv" value="OPERATOR" />
    <nvpair id="st-$hostname-host-list" name="pcmk_host_list" value="$hostname" />
    <nvpair id="st-$hostname-host-check" name="pcmk_host_check" value="static-list" />
  </instance_attributes>
  <operations >
    <op id="st-$hostname-monitor-10m" interval="10m" name="monitor" timeout="300s" />
  </operations>
</primitive>
EOF

cat > /tmp/fencing_constraints.xml << EOF
 <rsc_location id="l-st-$hostname" rsc="st-$hostname" score="-INFINITY" node="$hostname"/>
EOF

/usr/sbin/cibadmin -C --scope resources --xml-file /tmp/fencing.xml || /usr/sbin/cibadmin -R --scope resources --xml-file /tmp/fencing.xml
/usr/sbin/cibadmin -C --scope constraints --xml-file /tmp/fencing_constraints.xml || /usr/sbin/cibadmin -C --scope constraints --xml-file /tmp/fencing_constraints.xml

# Configure stonith action to poweroff instead of reboot
/usr/sbin/crm_attribute -t crm_config -n stonith-action -v poweroff

rm /tmp/fencing.xml
rm /tmp/fencing_constraints.xml

echo "Fencing configuration done"
