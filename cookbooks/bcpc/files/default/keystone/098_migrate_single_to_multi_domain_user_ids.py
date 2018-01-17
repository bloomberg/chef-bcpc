from keystone.common.sql import migration_helpers
import migrate
import json
import sqlalchemy as sql

_ASSIGNMENT_TABLE_NAME = 'assignment'
_ID_MAPPING_TABLE_NAME = 'id_mapping'
_BACKUP_TABLE_NAME = '__backup_assignment'


def upgrade(migrate_engine):
    """Migrate default-domain role assignments to use public_ids.

    If default domain is backed by ldap and the installation is migrated
    to utilize multi-domain configuration, existing users are issued new
    identifiers, stored in `id_mapping` table. This migration replaces the
    old with the new ids.
    """
    def backup_assignments():
        pass

    meta = sql.MetaData()
    meta.bind = migrate_engine
    session = sql.orm.sessionmaker(bind=migrate_engine)()

    assignment_table = sql.Table(_ASSIGNMENT_TABLE_NAME, meta, autoload=True)
    id_mapping_table = sql.Table(_ID_MAPPING_TABLE_NAME, meta, autoload=True)

    # Get the mappings for 'default' domain (public_id, [assignment_table.c])
    # There are likely fewer assignments than mappings, so loop over mappings
    cols = [id_mapping_table.c.public_id] + list(assignment_table.c)
    with_public_ids = sql.select(cols).select_from(assignment_table).where(
        sql.and_(
            assignment_table.c.actor_id == id_mapping_table.c.local_id,
            id_mapping_table.c.local_id != id_mapping_table.c.public_id,
            assignment_table.c.type == 'UserProject',
            id_mapping_table.c.entity_type == 'user'
        )
    )

    def _add_new_rows():
        # re-map the public_id as the actor_id for easy inserts
        remapped_public_id = sql.literal_column('public_id AS actor_id')
        wanted_cols = [
            assignment_table.c.type,
            remapped_public_id,
            assignment_table.c.target_id,
            assignment_table.c.role_id,
            assignment_table.c.inherited
        ]
        s = with_public_ids.with_only_columns(wanted_cols)
        insert = assignment_table.insert().from_select(assignment_table.c, s)
        session.execute(insert)
        session.commit()

    _add_new_rows()
    session.close()


def downgrade(migrate_engine):
    pass
