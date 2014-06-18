bcpc_jmxtrans Cookbook
======================
This cookbook enables JMX stats collection of JAVA processes using JMXTrans.

Requirements
------------
- Depends on the community JMXTrans cookbook

Attributes
----------
#### bcpc_jmxtrans::default
<table>
  <tr>
    <th>jmxtrans::default_queries</th>
    <th>ruby hash array</th>
    <th>JMX Mbeans and the properties which need to be queried for components like Kafka, HBase, JVM which need to be queried </th>
    <th>Refer the atribute file</th>
  </tr>

Usage
-----
1. Override the following JMXTrans attributes in role which will be assigned to the node on which JMX stats need to be collected.
2. Specify the default values for the attribute jmxtrans.servers. This will be overwritten by the default recipe
3. jmxtrans.servers is an array of name value pairs is for the information about the JAVA process
4.    jmxtrans.servers.name which is the host IP address where the JAVA process is running. In the case of BCPC this can be left blank since it will be overwritten in the recipe with the node IP where Chef client is executed.
5.    jmxtrans.servers.port the JMX port of the JAVA process
6.   jmxtrans.servers.type - the type of the process e.g. Kafka or JVM. This is used to pick the corresponding query from the default attributes.
7. The following is a sample from a role definition

default_attributes "jmxtrans" => {
    "servers" => [
                {
                   "name" => "",
                   "port" => "9999",
                   "type" => "kafka"
                 }
        ]
  }
8. Update the default attributes under the bcpc_jmxtrans cookbook
9. Update default['jmxtrans']['sw'] with the file name of the JMXTrans sw downloaded from GIT
10. Add new queries to existing query types or add new query types default['jmxtrans']['default_queries']['TYPE'] . Before adding new query types make sure that they are not already available in the community jmxtrans cookbook attribute file.


Contributing
------------
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors: Biju Nair
