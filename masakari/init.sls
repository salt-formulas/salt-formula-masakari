{%- from "masakari/map.jinja" import masakari with context %}

masakari_packages:
  pkg.installed:
  - names: {{ masakari.pkgs }}

ensure_latest_pip:
  pip.installed:
  - name: pip == 9.0.1
  - require:
    - masakari_packages
  - reload_modules: true


ensure_virtualenv:
  pip.installed:
  - name: virtualenv >= 15.1.0
  - require:
    - ensure_latest_pip

include:
{% if masakari.server.get('enabled', False) %}
- masakari.server
{%   if masakari.client.get('enabled', False) %}
- masakari.client
{%   endif %}
{% endif %}
{% if masakari.monitor.get('enabled', False) %}
- masakari.cluster
- masakari.monitor
{% endif %}
