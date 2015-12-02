import diamond.collector
import MySQLdb as mysql

class CloudCollector(diamond.collector.Collector):

    def get_default_config_help(self):
        config_help = super(CloudCollector, self).get_default_config_help()
        config_help.update({
            'cloud_collector': 'Send Openstack stats',
        })
        return config_help

    def get_default_config(self):
        """
        Returns the default collector settings
        """
        config = super(CloudCollector, self).get_default_config()
        config.update({
            'path':        'openstack',
            'path_prefix': '',
            'db_user': 'root',
            'db_password': 'password',
            'db_host': '127.0.0.1',
            'hostname': 'local',
        })
        return config


    def collect(self):
        cnx = mysql.connect(user=self.config['db_user'], passwd=self.config['db_password'], host=self.config['db_host'])
        cursor = cnx.cursor()

        # Glance total images size
        query = ("select sum(size) from glance.images where status = 'active' and deleted = 0")
        cursor.execute(query)
        row = cursor.fetchone()
        self.publish("glance.images_size", row[0])

        # Glance images size per_tenant
        query = ("select sum(size), kp.name, owner from glance.images gi join keystone.project kp on kp.id = gi.owner where status = 'active' and deleted = 0 group by kp.name")
        cursor.execute(query)

        for (size, tenant, owner) in cursor:
            self.publish("glance." + tenant + ".image_size", size)


        # Nova total usage
        query = ("select resource, sum(in_use) from nova.quota_usages where deleted = 0 group by resource")
        cursor.execute(query)

        for (resource, usage) in cursor:
            self.publish("nova." + resource, usage)

        # Nova per-tenant usage
        query = ("select kp.name, qu.project_id, qu.resource, q.hard_limit, sum(in_use) from nova.quota_usages qu left join nova.quotas q on qu.project_id = q.project_id and q.resource = qu.resource join keystone.project kp on kp.id = qu.project_id group by project_id, resource")
        cursor.execute(query)
        for (tenant, project_id, resource, hard_limit, usage) in cursor:
            self.publish("nova." + tenant + "." + resource, usage)


        # Cinder total usage
        query = ("select resource, sum(in_use) from cinder.quota_usages where deleted = 0 group by resource")
        cursor.execute(query)

        for (resource, usage) in cursor:
            self.publish("cinder." + resource, usage)

        # Cinder per-tenant usage
        query = ("select kp.name, qu.project_id, qu.resource, q.hard_limit, sum(in_use) from cinder.quota_usages qu left join cinder.quotas q on qu.project_id = q.project_id and q.resource = qu.resource join keystone.project kp on kp.id = qu.project_id group by project_id, resource")
        cursor.execute(query)
        for (tenant, project_id, resource, hard_limit, usage) in cursor:
            self.publish("cinder." + tenant + "." + resource, usage)


        cursor.close()
        cnx.close()
