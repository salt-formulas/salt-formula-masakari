{%- from "masakari/map.jinja" import masakari with context %}

masakari_monitor_packages:
  pkg.installed:
  - names: {{ masakari.monitor.pkgs }}

/opt/masakari-monitors.tgz:
  file.managed:
  - source: salt://masakari/files/masakari-monitors-{{ masakari.version }}.tar.gz
  - require:
    - masakari_packages
    - masakari_monitor_packages
    - /usr/local/virtualenvs/masakarimonitor

/usr/local/virtualenvs/masakarimonitor:
  virtualenv.managed:
  - system_site_packages: False
  - pip_pkgs:
    - libvirt-python==4.0.0
    - python-masakariclient==5.0.0
  - require:
    - ensure_virtualenv

/usr/local/virtualenvs/masakariclient:
  virtualenv.managed:
  - system_site_packages: False
  - pip_pkgs:
    - python-masakariclient
  - require:
    - ensure_virtualenv

masakarimonitor_install:
  pip.installed:
  - name: /opt/masakari-monitors.tgz
  - bin_env: /usr/local/virtualenvs/masakarimonitor
  - require:
    - masakari_packages
    - masakari_monitor_packages
    - /usr/local/virtualenvs/masakarimonitor

{%- if not salt['user.info']('masakari') and not masakari.server.get('enabled', False) %}
user_masakari:
  user.present:
  - name: masakari
  - home: /var/lib/masakari
  - shell: /bin/false
  - uid: 325
  - gid: 325
  - system: True
  - require_in:
    - masakarimonitor_install

group_masakari:
  group.present:
    - name: masakari
    - gid: 325
    - system: True
    - require_in:
      - user: user_masakari
{%- endif %}

/usr/local/virtualenvs/masakarimonitor/bin/systemctl:
  file.managed:
  - source: salt://masakari/files/bin/systemctl_wrapper.sh
  - mode: 0755

/usr/local/virtualenvs/masakarimonitor/bin/privsep-helper.sh:
  file.managed:
  - contents: |
      #!/bin/bash
      PATH=/usr/local/virtualenvs/masakarimonitor/bin:$PATH /usr/local/virtualenvs/masakarimonitor/bin/privsep-helper $@
  - mode: 0755

/etc/sudoers.d/99-masakari-user:
  file.managed:
  - contents: |
      masakari ALL = (root) NOPASSWD: /usr/local/virtualenvs/masakarimonitor/bin/privsep-helper.sh *
  - user: root
  - group: root
  - mode: 440

/usr/local/virtualenvs/masakarimonitor/lib/python2.7/site-packages/oslo_log/formatters.py:
  file.patch:
  - source: salt://masakari/files/oslo.log.formatters.patch
  - hash: md5:9f68bfe5e6b16260074b75c01df0b4df
  - dry_run_first: True
  - onlyif:
    - md5sum /usr/local/virtualenvs/masakarimonitor/lib/python2.7/site-packages/oslo_log/formatters.py | grep 8569b329e0ca9ee9de96acd0df6a666c
  - require:
    - masakarimonitor_install

/etc/masakarimonitors:
  file.directory:
  - owner: masakari
  - group: masakari
  - mode: 0750
  {%- if not salt['user.info']('masakari') %}
  - require:
    - user: user_masakari
    - group: group_masakari
  {%- endif %}

/etc/masakarimonitors/hostmonitor.conf:
  file.managed:
  - source: salt://masakari/files/etc/masakarimonitors/hostmonitor.conf
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakarimonitors

/etc/masakarimonitors/masakarimonitors.conf:
  file.managed:
  - source: salt://masakari/files/etc/masakarimonitors/masakarimonitors.conf
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakarimonitors

/etc/masakarimonitors/proc.list:
  file.managed:
  - source: salt://masakari/files/etc/masakarimonitors/proc.list
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakarimonitors

/etc/masakarimonitors/process_list.yaml:
  file.managed:
  - source: salt://masakari/files/etc/masakarimonitors/process_list.yaml
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakarimonitors

/etc/masakarimonitors/processmonitor.conf:
  file.managed:
  - source: salt://masakari/files/etc/masakarimonitors/processmonitor.conf
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakarimonitors

{%- if grains['oscodename'] == 'trusty' %}
/etc/init/masakari-hostmonitor.conf:
  file.managed:
  - source: salt://masakari/files/etc/init/masakari-hostmonitor.conf
  - owner: root
  - require:
    - masakarimonitor_install

/etc/init/masakari-instancemonitor.conf:
  file.managed:
  - source: salt://masakari/files/etc/init/masakari-instancemonitor.conf
  - owner: root
  - require:
    - masakarimonitor_install

/etc/init/masakari-processmonitor.conf:
  file.managed:
  - source: salt://masakari/files/etc/init/masakari-processmonitor.conf
  - owner: root
  - require:
    - masakarimonitor_install
{% else %}
/lib/systemd/system/masakari-hostmonitor.service:
  file.managed:
  - source: salt://masakari/files/etc/systemd/masakari-hostmonitor.service
  - owner: root
  - require:
    - masakarimonitor_install

/lib/systemd/system/masakari-instancemonitor.service:
  file.managed:
  - source: salt://masakari/files/etc/systemd/masakari-instancemonitor.service
  - owner: root
  - require:
    - masakarimonitor_install

/lib/systemd/system/masakari-processmonitor.service:
  file.managed:
  - source: salt://masakari/files/etc/systemd/masakari-processmonitor.service
  - owner: root
  - require:
    - masakarimonitor_install

service.systemctl_reload:
  module.run:
    - onchanges:
      - file: /lib/systemd/system/masakari-hostmonitor.service
      - file: /lib/systemd/system/masakari-instancemonitor.service
      - file: /lib/systemd/system/masakari-processmonitor.service
{% endif %}

masakarimonitor_services:
  service.running:
  - enable: true
  - names: {{ masakari.monitor.services }}
  - require:
{%- if grains['oscodename'] == 'trusty' %}
    - file: /etc/init/masakari-hostmonitor.conf
    - file: /etc/init/masakari-instancemonitor.conf
    - file: /etc/init/masakari-processmonitor.conf
{% else %}
    - file: /lib/systemd/system/masakari-hostmonitor.service
    - file: /lib/systemd/system/masakari-instancemonitor.service
    - file: /lib/systemd/system/masakari-processmonitor.service
{% endif %}
    - file: /etc/sudoers.d/99-masakari-user
  - watch:
    - file: /etc/masakarimonitors/hostmonitor.conf
    - file: /etc/masakarimonitors/masakarimonitors.conf
    - file: /etc/masakarimonitors/proc.list
    - file: /etc/masakarimonitors/process_list.yaml
    - file: /etc/masakarimonitors/processmonitor.conf
{%- if grains['oscodename'] == 'trusty' %}
    - file: /etc/init/masakari-hostmonitor.conf
    - file: /etc/init/masakari-instancemonitor.conf
    - file: /etc/init/masakari-processmonitor.conf
{% else %}
    - file: /lib/systemd/system/masakari-hostmonitor.service
    - file: /lib/systemd/system/masakari-instancemonitor.service
    - file: /lib/systemd/system/masakari-processmonitor.service
{% endif %}

## Add node to masakari api database
{%- set ident = masakari.monitor.openstack_auth %}

{%- if ident.get('api_version', '3') == '3' %}
{%- set version = "" %}
{%- else %}
{%- set version = "v2.0" %}
{%- endif %}

{%- if ident.get('protocol', 'http') == 'http' %}
{%- set protocol = 'http' %}
{%- else %}
{%- set protocol = 'https' %}
{%- endif %}

# Create segment {{ masakari.corosync.clustername }} and/or host {{ pillar.linux.system.name }}
add_monitor_to_masakari:
  cmd.script:
    - name: salt://masakari/files/bin/create_masakari_host.sh
    - args: "{{ masakari.corosync.clustername }} {{ pillar.linux.system.name }}"
    - env:
      - OS_IDENTITY_API_VERSION: "{{ ident.get('api_version', '3') }}"
      - OS_AUTH_URL: "{{ protocol }}://{{ ident.host }}:{{ ident.port|string }}/{{ version }}"
      - OS_REGION_NAME: "{{ ident.admin_region }}"
      - OS_USER_DOMAIN_NAME: "{{ ident.admin_domain }}"
      - OS_PROJECT_DOMAIN_NAME: "{{ ident.admin_domain }}"
      - OS_PROJECT_NAME: "{{ ident.admin_tenant }}"
      - OS_TENANT_NAME: "{{ ident.admin_tenant }}"
      - OS_USERNAME: "{{ ident.admin_user }}"
      - OS_PASSWORD: "{{ ident.admin_password }}"
    - require:
      - service: masakarimonitor_services
