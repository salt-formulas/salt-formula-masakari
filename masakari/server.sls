{%- from "masakari/map.jinja" import masakari with context %}

/opt/masakari.tgz:
  file.managed:
  - source: salt://masakari/files/masakari-{{ masakari.version }}.tar.gz
  - require:
    - masakari_packages

/usr/local/virtualenvs/masakari:
  virtualenv.managed:
  - system_site_packages: False
  - pip_pkgs:
    - pymysql
    - python-memcached
  - require:
    - ensure_virtualenv

masakari_install:
  pip.installed:
  - names:
    - /opt/masakari.tgz
    - git+https://github.com/openstack/python-masakariclient.git
  - bin_env: /usr/local/virtualenvs/masakari
  - require:
    - /usr/local/virtualenvs/masakari
  - onchanges:
    - file: /opt/masakari.tgz

{%- if not salt['user.info']('masakari') %}
user_masakari:
  user.present:
  - name: masakari
  - home: /var/lib/masakari
  - shell: /bin/false
  - uid: 325
  - gid: 325
  - system: True
  - require_in:
    - masakari_install

group_masakari:
  group.present:
    - name: masakari
    - gid: 325
    - system: True
    - require_in:
      - user: user_masakari
{%- endif %}

/etc/masakari:
  file.directory:
  - owner: masakari
  - group: masakari
  - mode: 0750
  {%- if not salt['user.info']('masakari') %}
  - require:
    - user: user_masakari
    - group: group_masakari
  {%- endif %}

/etc/masakari/masakari.conf:
  file.managed:
  - source: salt://masakari/files/etc/masakari/masakari.conf
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakari

/etc/masakari/api-paste.ini:
  file.managed:
  - source: salt://masakari/files/etc/masakari/api-paste.ini
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakari


/etc/masakari/policy.json:
  file.managed:
  - source: salt://masakari/files/etc/masakari/policy.json
  - owner: masakari
  - template: jinja
  - require:
    - file: /etc/masakari

/usr/local/bin/masakari:
  file.symlink:
  - target: /usr/local/virtualenvs/masakari/bin/masakari
  - require:
    - masakari_install

masakari_syncdb:
  cmd.run:
  - names:
    - /usr/local/virtualenvs/masakari/bin/masakari-manage db sync
  - require:
    - file: /etc/masakari/masakari.conf

/etc/init/masakari-api.conf:
  file.managed:
  - source: salt://masakari/files/etc/init/masakari-api.conf
  - owner: root
  - require:
    - masakari_install

/etc/init/masakari-engine.conf:
  file.managed:
  - source: salt://masakari/files/etc/init/masakari-engine.conf
  - owner: root
  - require:
    - masakari_install

masakari_services:
  service.running:
  - enable: true
  - names: {{ masakari.server.services }}
  - require:
    - cmd: masakari_syncdb
    - file: /etc/init/masakari-api.conf
    - file: /etc/init/masakari-engine.conf
  - watch:
    - file: /etc/masakari/masakari.conf
    - file: /etc/masakari/api-paste.ini
    - file: /etc/masakari/policy.json
    - file: /etc/init/masakari-api.conf
    - file: /etc/init/masakari-engine.conf
