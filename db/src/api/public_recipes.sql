-- For usage by the anonymous role (public access) for rich link previews
CREATE OR REPLACE VIEW api.public_recipes AS
SELECT 
  id,
  title,
  description,
  images
FROM 
  api.recipes;
  
