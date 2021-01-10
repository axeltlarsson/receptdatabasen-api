# Convert the images jsonb url to use .jpeg instead of .png

This was rather tricky actually:

```sql
begin;

with new as (
select id, images,
  json_build_array(json_build_object('url', replace(replace(jsonb_path_query(images, '$[*].url ? (@ like_regex ".*png")')::text, 'png', 'jpeg'), '"', ''))) as images_new
  from recipe order by id

)
update recipe
set images = new.images_new
from new
where new.id = recipe.id
```
