-- Grant access to webuser
grant select on arc.answer_choices to webuser;
grant select, update on arc.progress to webuser;
grant select on arc.roles to webuser;
grant select on arc.scenarios to webuser;
grant select on arc.scenes to webuser;

grant select, usage on all sequences in schema arc to webuser;

-- get user id
Drop function basic_auth.user_id(email text);
create function basic_auth.user_id(email text) returns text
    language plpgsql
as
$$
begin
  return (
  select id from basic_auth.users
   where users.email = user_id.email
  );
end;
$$;

alter function basic_auth.user_id(text) owner to hao;

-- modify arc.login to return id as well
create or replace function
arc.login(email text, pass text) returns basic_auth.jwt_token as $$
declare
  _role name;
  user_id text;
  result basic_auth.jwt_token;
begin
  -- check email and password
  select basic_auth.user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;

  select basic_auth.user_id(email) into user_id;
  select sign(
      row_to_json(r), 'reallyreallyreallyreallyverysafe'
    ) as token
    from (
      select _role as role, login.email as email, user_id as id,
         extract(epoch from now())::integer + 60*60 as exp
    ) r
    into result;
  return result;
end;
$$ language plpgsql security definer;


