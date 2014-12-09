#!/usr/bin/env python

""" Update DNS Records for Floating IPs

This script runs periodically from cron (every minute, usually),
and performs the following tasks:

1. Populate the pdns.keystone_project table with required data
2. Run update_records() mysql function.

The end result should be an updated set of A and PTR records in
the pdns.records table.

Usage:
./populate_dns.py <tenant_tree_dn> <vip address> <ldap user> <ldap pass> <mysql pdns user> <mysql pdns pass>

Example from a virtual test cluster:
./populate_dns.py "ou=Tenants,dc=bcpc,dc=example,dc=com" 10.0.100.5 "cn=Directory Manager" "n1fVz_YXZaHKl5osEgv7" "pdns" "DRDtsia5wJPaeOFDUG_7"

"tenant_tree_dn" should equal the value of the tenant_tree_dn setting 
in /etc/keystone/keystone.conf

The VIP address is used to connect to both ldap and to mysql. 
The assumption is that the VIP is managing both of these services. 
If that changes, this will have to be adjusted as well.

"""

import sys
import argparse

import ldap
import MySQLdb




class Keystone:

  def __init__(self, vip, tenant_dn, bind_dn, password):
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
    self.conn.autocommit = False


  """ update_projects(project_source)

  Give this an object which exposes a generator method called projects() and returns
  dicts with keys "project" and "project_id". It doesn't have to be Keystone.
  """
  def update_projects(self, project_source):

    insert = """insert into keystone_project(id, name)
                values(%s, %s)"""

    cursor = self.conn.cursor()

    cursor.execute("delete from keystone_project")

    for project in project_source.projects():
      print "Adding Project: " + project['project'] + " ID: " + project['project_id']
      cursor.execute(insert, [ project['project_id'], project['project'] ])

    self.conn.commit()

  def update_records(self):

    cursor = self.conn.cursor()

    cursor.callproc('populate_records')
    self.conn.commit()


parser = argparse.ArgumentParser(description="Load Keystone LDAP info " +
                                 "into PDNS databsae and update A and PTR " +
                                 "records for VMs with associated floating IPs.")
parser.add_argument("-t", "--tenant-tree-dn", 
                  action="store", type=str, dest="tenant_dn", required=True,
                  help="tenant_tree_dn setting from /etc/keystone/keystone.conf" )
parser.add_argument("-v", "--vip",
                  action="store", type=str, dest="vip", required=True,
                  help="The cluster's management VIP address. Should serve " +
                      "both LDAP and MySQL.")
parser.add_argument('-u', "--ldap-user",
                  action="store", type=str, dest="ldap_user", required=True,
                  help="User DN to connect to LDAP on VIP (eg value of " +
                    "'389ds-rootdn-user' from data bag)")
parser.add_argument("-p", "--ldap-password",
                  action="store", type=str, dest="ldap_pass", required=True,
                  help="Password for ldap user")
parser.add_argument('-U', "--mysql-user", required=True,
                  action="store", type=str, dest="mysql_user",
                  help="User to connect to 'pdns' database on VIP")
parser.add_argument("-P", "--mysql-password", required=True,
                  action="store", type=str, dest="mysql_pass",
                  help="Password for mysql user")

args = parser.parse_args()

keystone = Keystone(args.vip, args.tenant_dn, args.ldap_user, args.ldap_pass)
pdns = PDNS(args.vip, args.mysql_user, args.mysql_pass)

pdns.update_projects(keystone)
pdns.update_records()

