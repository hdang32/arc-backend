create user jeannie with password 'haoisgreat123';
grant usage on schema arc to jeannie;
grant select, insert, update, delete on all tables in schema arc to jeannie;
grant select, usage on all sequences in schema arc to jeannie;

grant usage on schema basic_auth to jeannie;
grant select, insert, update, delete on all tables in schema basic_auth to jeannie;
grant select, usage on all sequences in schema basic_auth to jeannie;
