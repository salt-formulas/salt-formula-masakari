{%- from "masakari/map.jinja" import masakari with context %}

masakari_cluster_packages:
  pkg.installed:
  - names: {{ masakari.cluster.pkgs }}

/etc/default/corosync:
  file.managed:
  - contents: |
      # start corosync at boot [yes|no]
      START=yes

/etc/corosync/uidgid.d:
  file.directory:
  - dir_mode: 755
  - file_mode: 644

/etc/corosync/uidgid.d/hacluster:
  file.managed:
  - contents: |
      uidgid {
        uid: hacluster
        gid: haclient
      }

/etc/corosync/corosync.conf:
  file.managed:
  - source: salt://masakari/files/etc/corosync/corosync.conf
  - template: jinja
  - require:
    - pkg: masakari_cluster_packages

corosync_service:
  service.running:
  - enable: true
  - name: corosync
  - require:
    - file: /etc/default/corosync
    - file: /etc/corosync/corosync.conf
    - file: /etc/corosync/uidgid.d/hacluster
  - watch:
    - file: /etc/default/corosync
    - file: /etc/corosync/corosync.conf

pacemaker_service:
  service.running:
  - enable: true
  - name: pacemaker
  - require:
    - service: corosync_service

salt://masakari/files/bin/configure_fencing.sh:
  cmd.script:
  - require:
    - service: corosync_service
    - service: pacemaker_service
  - unless:
    - cibadmin --query -o resource | grep st-$(hostname)
