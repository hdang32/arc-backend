create database arc;

create role web_anon nologin;
grant usage on schema arc to web_anon;

-- Grant access to PostgREST to switch roles to web_anon user
create role authenticator noinherit login password 'mysecretpassword';
grant web_anon to authenticator;

-- Create testing table
create table arc.test_table
(
	id serial not null
		constraint test_table_pk
			primary key,
	foo text
);

alter table arc.test_table owner to hao;

-- User role for regular users in basic_auth
CREATE ROLE webuser NOLOGIN;
GRANT webuser to authenticator;

CREATE EXTENSION pgcrypto;
CREATE EXTENSION pgjwt;

-- We put things inside the basic_auth schema to hide
-- them from public view. Certain public procs/views will
-- refer to helpers and tables inside.
create schema if not exists basic_auth;

create table if not exists
basic_auth.users (
  id       serial primary key,
  name     text not null check (length(name) < 512),
  email    text not null check ( email ~* '^.+@.+\..+$' ),
  pass     text not null check (length(pass) < 512),
  role     name not null check (length(role) < 512)
);

-- Ensure the role an inserted user has exists in the DB

create or replace function
basic_auth.check_role_exists() returns trigger as $$
begin
  if not exists (select 1 from pg_roles as r where r.rolname = new.role) then
    raise foreign_key_violation using message =
      'unknown database role: ' || new.role;
    return null;
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists ensure_user_role_exists on basic_auth.users;
create constraint trigger ensure_user_role_exists
  after insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.check_role_exists();

-- Encrypt our passwords

create or replace function
basic_auth.encrypt_pass() returns trigger as $$
begin
  if tg_op = 'INSERT' or new.pass <> old.pass then
    new.pass = crypt(new.pass, gen_salt('bf'));
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists encrypt_pass on basic_auth.users;
create trigger encrypt_pass
  before insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.encrypt_pass();

create or replace function
basic_auth.user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
  select role from basic_auth.users
   where users.email = user_role.email
     and users.pass = crypt(user_role.pass, users.pass)
  );
end;
$$;

CREATE TYPE basic_auth.jwt_token AS (
  token text
);

-- login should be on your exposed schema
create or replace function
arc.login(email text, pass text) returns basic_auth.jwt_token as $$
declare
  _role name;
  result basic_auth.jwt_token;
begin
  -- check email and password
  select basic_auth.user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;

  select sign(
      row_to_json(r), 'reallyreallyreallyreallyverysafe'
    ) as token
    from (
      select _role as role, login.email as email,
         extract(epoch from now())::integer + 60*60 as exp
    ) r
    into result;
  return result;
end;
$$ language plpgsql security definer;

grant execute on function arc.login(text,text) to web_anon;

-- Allow webuser to do CRUD on test table
grant usage on schema arc to webuser;
grant select, insert, update, delete on arc.test_table to webuser;

-- Create signup function for new users
create or replace function
    arc.signup(name text, email text, pass text) returns basic_auth.jwt_token as $$
declare
    _role name;
    result basic_auth.jwt_token;
begin
    -- check email and password
    insert into basic_auth.users (name, email, pass, role)
    values (signup.name, signup.email, signup.pass, 'webuser');
    select basic_auth.user_role(email, pass) into _role;
    if _role is null then
        raise invalid_password using message = 'invalid user or password';
    end if;

    select sign(
                   row_to_json(r), 'reallyreallyreallyreallyverysafe'
               ) as token
    from (
             select _role as role, signup.email as email,
                    extract(epoch from now())::integer + 60*60 as exp
         ) r
    into result;
    return result;
end;
$$ language plpgsql security definer;

grant execute on function arc.signup(text, text, text) to web_anon;
