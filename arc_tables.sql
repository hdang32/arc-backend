create table scenarios
(
    id          serial not null
        constraint pk_scenarios_id
            primary key,
    description text   not null,
    title       text   not null
);

alter table scenarios
    owner to hao;

create table roles
(
    id          serial  not null
        constraint roles_pk
            primary key,
    name        text    not null,
    scenario_id integer not null
        constraint scenario_id
            references scenarios
);

alter table roles
    owner to hao;

create table scenes
(
    id          serial not null
        constraint scenes_pk
            primary key,
    description text   not null,
    image_link  text,
    role_id     integer
        constraint role_id
            references roles
            on update cascade on delete cascade,
    type        text   not null
);

alter table scenes
    owner to hao;

create table answer_choices
(
    id               serial  not null
        constraint answer_choices_pk
            primary key,
    text             text    not null,
    current_scene_id integer not null
        constraint current_scene_id
            references scenes
            on update cascade on delete cascade,
    next_scene_id    integer not null
        constraint next_scene_id
            references scenes
            on update cascade on delete cascade
);

alter table answer_choices
    owner to hao;

create table progress
(
    id           serial  not null
        constraint progress_pk
            primary key,
    user_id      integer not null
        constraint user_id
            references basic_auth.users
            on update cascade on delete cascade,
    role_id      integer not null
        constraint role_id
            references roles
            on update cascade on delete cascade,
    scene_id     integer not null
        constraint scene_id
            references scenes
            on update cascade on delete cascade,
    is_completed boolean default false
);

alter table progress
    owner to hao;

create unique index progress_id_uindex
    on progress (id);