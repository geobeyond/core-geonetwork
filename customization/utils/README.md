# Importing users from Geostore

Users and groups are imported from Geostore using the trigger function [migrate_user_groups_from_gn](./trigger.sql).

The table schema_geostore.gs_usergroup_members contains two triggers:

```sql
create trigger update_geonetwork_insert after
insert
    on
    schema_geostore.gs_usergroup_members for each row execute function schema_geonetwork.migrate_user_groups_from_gn();

create trigger update_geonetwork_delete after
delete
    on
    schema_geostore.gs_usergroup_members for each row execute function schema_geonetwork.migrate_user_groups_from_gn();
```

