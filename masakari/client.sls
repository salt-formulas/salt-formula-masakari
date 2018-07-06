{%- from "masakari/map.jinja" import masakari with context %}
{%- if masakari.client.get('enabled', False) %}

{%- for host_name, segment in salt['mine.get']('masakari:corosync:clustername', 'masakari.clustername', 'pillar').items() %}

# Create segment {{segment}} and/or host {{host_name}}
masakari_segment_{{segment}}_{{host_name}}:
  cmd.script:
    - name: salt://masakari/files/bin/create_masakari_host.sh
    - args: "{{segment}} {{host_name.split('.')[0]}}"
    - require:
      - service: masakari_services

{%- endfor %}
{%- endif %}
