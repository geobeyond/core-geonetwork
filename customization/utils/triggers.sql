```

-- DROP FUNCTION schema_geonetwork.migrate_user_groups_from_gn();

  

CREATE OR REPLACE FUNCTION schema_geonetwork.migrate_user_groups_from_gn()

RETURNS trigger

LANGUAGE plpgsql

AS $function$

BEGIN

-- Insert or update the groups with groupname like 'EDIT_%' into schema_geonetwork.groups

INSERT INTO schema_geonetwork."groups" (id, "name", description)

SELECT id, SUBSTRING(groupname FROM 6), description

FROM schema_geostore.gs_usergroup

WHERE groupname LIKE 'EDIT_%'

ON CONFLICT (id) DO UPDATE

SET "name" = EXCLUDED."name", description = EXCLUDED.description;

  

-- Insert or update users from schema_geostore.gs_user into schema_geonetwork.users

INSERT INTO schema_geonetwork.users (id, username, name, "password", profile, isenabled)

SELECT id, "name", "name", '',

CASE

WHEN user_role = 'ADMIN' THEN 0

WHEN user_role = 'USER' THEN 4

WHEN user_role = 'GUEST' THEN 4

ELSE 4 -- Default to 'Registered User' if no matching role is found

END AS profile,

LOWER(enabled)

FROM schema_geostore.gs_user

ON CONFLICT (id) DO UPDATE

SET username = EXCLUDED.username, name = EXCLUDED.name, "password" = EXCLUDED."password", profile = EXCLUDED.profile, isenabled = EXCLUDED.isenabled;

  

-- We fully reload it every time

DELETE FROM schema_geonetwork.usergroups;

  

-- Insert usergroup memberships for EDITORS (3)

INSERT INTO schema_geonetwork.usergroups (groupid, profile, userid)

SELECT gn.id, 3, gm.user_id

FROM schema_geostore.gs_usergroup_members gm

JOIN schema_geostore.gs_usergroup gg ON gm.group_id = gg.id

JOIN schema_geonetwork.users u ON gm.user_id = u.id

JOIN schema_geonetwork."groups" gn ON gn."name" = SUBSTRING(gg.groupname FROM 6)

WHERE gg.groupname LIKE 'EDIT_%';

  

-- Insert usergroup memberships for REVIEWERS (2)

INSERT INTO schema_geonetwork.usergroups (groupid, profile, userid)

SELECT gn.id, 2, gm.user_id

FROM schema_geostore.gs_usergroup_members gm

JOIN schema_geostore.gs_usergroup gg ON gm.group_id = gg.id

JOIN schema_geonetwork.users u ON gm.user_id = u.id

JOIN schema_geonetwork."groups" gn ON gn."name" = SUBSTRING(gg.groupname FROM 7)

WHERE gg.groupname LIKE 'ADMIN_%';

  

-- Insert or update emails into schema_geonetwork.email from schema_geostore.gs_user_attribute where name = 'email'

DELETE FROM schema_geonetwork.email

WHERE user_id IN (SELECT ua.user_id

FROM schema_geostore.gs_user_attribute ua

WHERE ua."name" = 'email');

  

-- Insert emails into schema_geonetwork.email from schema_geostore.gs_user_attribute where name = 'email'

INSERT INTO schema_geonetwork.email (user_id, email)

SELECT DISTINCT ua.user_id, ua.string

FROM schema_geostore.gs_user_attribute ua

JOIN schema_geonetwork.users u ON ua.user_id = u.id

WHERE ua."name" = 'email';

  

-- Insert descriptions into schema_geonetwork.groupsdes for each group, for 'it' and 'en' languages

INSERT INTO schema_geonetwork.groupsdes (iddes, "label", langid)

SELECT id, "name", 'it'

FROM schema_geonetwork."groups"

ON CONFLICT (iddes, langid) DO NOTHING;

  

INSERT INTO schema_geonetwork.groupsdes (iddes, "label", langid)

SELECT id, "name", 'en'

FROM schema_geonetwork."groups"

ON CONFLICT (iddes, langid) DO NOTHING;

  

-- Insert or update group-category relationships for each group and each category

DELETE FROM schema_geonetwork.group_category

WHERE (group_id, category_id) IN (

SELECT g.id, c.id

FROM schema_geonetwork."groups" g, schema_geonetwork.categories c

);

  

-- Insert group-category relationships for each group and each category

INSERT INTO schema_geonetwork.group_category (group_id, category_id)

SELECT DISTINCT g.id, c.id

FROM schema_geonetwork."groups" g, schema_geonetwork.categories c;

  

-- Update user profile with the lowest value available in schema_geonetwork.usergroups for the same user id

UPDATE schema_geonetwork.users u

SET profile = sub.min_profile

FROM (

SELECT userid, MIN(profile) AS min_profile

FROM schema_geonetwork.usergroups

GROUP BY userid

) sub

WHERE u.id = sub.userid and profile > 0;

  

-- Update sequences with the maximum current id values

PERFORM setval('schema_geonetwork.group_id_seq', (SELECT MAX(id) FROM schema_geonetwork."groups"), true);

PERFORM setval('schema_geonetwork.user_id_seq', (SELECT MAX(id) FROM schema_geonetwork.users), true);

RETURN NULL;

END;

$function$

;
```

