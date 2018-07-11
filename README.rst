=====
Salt formula for Virtual Machine High Availability (VMHA) as a service (Masakari)
=====

Some things to consider:

* Fencing will be configured using ipmitool, and assumes the presence of a iDRAC (or similar) for fencing purposes

* Corosync / Pacemaker has a limit of 16 nodes per cluster. Make sure you cluster the nodes appropriately.


Sample pillars
==============
Masakari API / Engine (see also service/server/cluster.yml):

.. code-block:: yaml

    masakari:
      server:
        enabled: true
        version: ${_param:masakari_version}
        debug: false
        api:
          address: ${_param:cluster_local_address}
          port: 15868
        cache:
          engine: memcached
          members:
          - host: ${_param:cluster_node01_address}
            port: 11211
          - host: ${_param:cluster_node02_address}
            port: 11211
          - host: ${_param:cluster_node03_address}
            port: 11211
        database:
          engine: mysql
          host: ${_param:openstack_database_address}
          port: 3306
          name: masakari
          user: masakari
          password: ${_param:mysql_masakari_password}
        identity:
          engine: keystone
          protocol: http
          host: ${_param:cluster_vip_address}
          port: 35357
          user: masakari
          password: ${_param:keystone_masakari_password}
          tenant: service
          region: ${_param:openstack_region}
        message_queue:
          engine: rabbitmq
          port: 5672
          user: openstack
          password: ${_param:rabbitmq_openstack_password}
          virtual_host: '/openstack'
          members:
            - host: ${_param:openstack_message_queue_node01_address}
            - host: ${_param:openstack_message_queue_node02_address}
            - host: ${_param:openstack_message_queue_node03_address}


Masakari monitor (compute node, see metadata/service/monitor/single.yml)

.. code-block:: yaml

      masakari:
        corosync:
          clustername: masakari
          multicast:
            interface: eth0
            bind_address: ${_param:cluster_local_address}
            port: 5405
            rrp_bind_address: ${_param:deploy_address}
          nodes:
            target: G@roles:nova.compute

        monitor:
          enabled: true
          version: ${_param:masakari_version}
          debug: false
          stonith_type: ipmi

          openstack_auth:
            protocol: http
            host: ${_param:cluster_vip_address}
            port: 35357
            admin_user: masakari
            admin_password: ${_param:keystone_masakari_password}
            admin_tenant: service
            admin_domain: default
            admin_region: ${_param:openstack_region}

      # Add a mine function that we can re-use when registering hosts in masakari.
      mine_functions:
        masakari.clustername:
          - mine_function: pillar.get
          - masakari:corosync:clustername



Installation
============

Install masakari api and masakari engine on the controller nodes
----------------------------------------------------------------

* Create database
    ``salt -C 'I@galera:master' state.sls galera``

* Add keystone user and endpoint
    ``salt -C 'I@keystone:client' state.sls keystone.client``

* Update salt minion state of monitors
    ``salt -C 'I@masakari:monitor' state.sls salt.minion``

* verify that the salt mine has been updated (should return the clustername for all nodes)
    ``salt 'cfg01.*' mine.get '*' masakari.clustername``

* Install masakari server
    ``salt -C 'I@masakari:server' state.sls haproxy,masakari -b 1``


Compute node installation
-------------------------

* Install masakari monitors (on the compute nodes)
    ``salt -C 'I@masakari:monitor' state.sls masakari``
