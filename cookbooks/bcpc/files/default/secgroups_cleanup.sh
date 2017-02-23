#!/bin/bash

# cleans up stale security group associations from deleted instances
mysql -e "USE nova; CREATE TABLE IF NOT EXISTS security_group_instance_association_archive LIKE security_group_instance_association; START TRANSACTION; INSERT security_group_instance_association_archive SELECT * FROM security_group_instance_association WHERE deleted > 0 AND instance_uuid NOT IN (SELECT uuid FROM instances WHERE deleted = 0); DELETE FROM security_group_instance_association WHERE id IN (SELECT id FROM security_group_instance_association_archive); COMMIT;"
