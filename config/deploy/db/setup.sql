-- Additional databases for Rails Solid Cache, Solid Queue, and Solid Cable.
-- The primary database (cut_list_web_app_production) is created automatically
-- via POSTGRES_DB in the container environment.

CREATE DATABASE cut_list_web_app_production_cache;
CREATE DATABASE cut_list_web_app_production_queue;
CREATE DATABASE cut_list_web_app_production_cable;
