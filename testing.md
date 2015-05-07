BCPC Cluster Testing Overview
===============================

Rally
Consists of the following files:
keystone_populate.sh
rally_keystone_populate.rb
rally.rb
rally.conf.erb
rally.existing.json.erb
default.rb
*keystone.rb includes the recipe keystone_populate.rb at the bottom
*rally.existing.json.erb is a json file that contains info on the existing cloud
*default.rb on has one variable at the moment for Rally which is the user name

In addition, build_bins.sh has a rally section at the bottom that includes the dependency packages that are not present via dpkg already.

Rally uses the json or yaml files in the samples directory to feed the tests.
