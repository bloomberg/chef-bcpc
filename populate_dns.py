#!/usr/bin/env python

""" Update DNS Records for Floating IPs

This script runs periodically from cron (every minute, usually),
and performs the following tasks:

1. Populate the pdns.keystone_project table with required data
2. Run update_records() mysql function.

The end result should be an updated set of A and PTR records in
the pdns.records table.

Usage:
./populate_dns.py <tenant_tree_dn> <vip address> <ldap user> <ldap pass> <mysql user> <mysql pass>

"tenant_tree_dn" should equal the value of the tenant_tree_dn setting 
in /etc/keystone/keystone.conf

The VIP address is used to connect to both ldap and to mysql. 
The assumption is that the VIP is managing both of these services. 
If that changes, this will have to be adjusted as well.

"""

import sys
import ldap
import MySQLdb

# Grab command line arguments
tenant_dn = sys.argv[1]
vip = sys.argv[2] 

ldap_user = sys.argv[3] 
ldap_pass = sys.argv[4]

mysql_user = sys.argv[5]
mysql_pass = sys.argv[6]

class Keystone:

  def __init__(self, tenant_dn, ip, bind_dn, password):
    self.conn = ldap.initialize('ldap://' + vip)
    self.tenant_dn = tenant_dn
    self.conn.bind_s(bind_dn, password, ldap.AUTH_SIMPLE)

  def projects(self):
    scope = ldap.SCOPE_ONELEVEL
    filter = "ou=*"
    retrieve_attributes = ['cn', 'ou'] # cn = project guid, ou = project name
    timeout = 5 # seconds

    result_id = self.conn.search(self.tenant_dn, scope, filter, retrieve_attributes)
    result_type, result_data = self.conn.result(result_id, timeout)
    
    for project in result_data:
      yield { 'project': project[1]['ou'][0], 'project_id': project[1]['cn'][0] }
      

class PDNS:
  def __init__(self, ip, username, password):
    print "Connect to mysql at " + ip + " as " + username
    self.conn = MySQLdb.connect(ip, username, password, "pdns")

    

  """ update_projects(project_source)

  Give this an object which exposes a generator method called projects() and returns 
  dicts with keys "project" and "project_id". It doesn't have to be Keystone.
  """
  def update_projects(self, project_source):

    insert = """insert into keystone_project(id, name) 
                values('%s', '%s')"""
    
    cursor = self.conn.cursor()
    
    self.conn.start_transaction(True, 'READ COMMITTED', False)

    cursor.execute("delete from keystone_project")

    for project in project_source.projects():
      print "Adding Project: " + project['project'] + " ID: " + project['project_id']
      cursor.execute(insert, [ project['project_id'], project['project'] ])

    self.conn.commit()

  def update_records(self):

    cursor = self.conn.cursor()

    self.conn.start_transaction(True, 'READ COMMITTED', False)
    cursor.execute('populate_records()')
    self.conn.commit()



keystone = Keystone(tenant_dn, vip, ldap_user, ldap_pass)

pdns = PDNS(vip, mysql_user, mysql_pass)
pdns.update_projects(keystone)
pdns.update_records()


