--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6
-- Dumped by pg_dump version 16.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: _class_body_get(uuid, uuid, jsonb, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._class_body_get(_schoolid uuid, _classid uuid, _input jsonb, _date date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    key text;
    class_body jsonb;
    absentPath text;
    absent_global jsonb;

BEGIN
	class_body := (SELECT data -> _classID::text FROM schools_data WHERE school_id = _schoolID
		AND date = _date);

    IF NOT (class_body IS NULL) THEN
        absentPath := 'absent';
        absent_global := '[]'::jsonb;

        -- Итерация по ключам (cause_type)
        FOR key IN
            SELECT jsonb_array_elements_text('["ORVI", "respectful", "not_respectful"]')
        LOOP
            IF (_input -> absentPath ? key) THEN
                -- Установка значения из входных данных в массив
                class_body := jsonb_set(
                    class_body,
                    ('{' || absentPath || ',' || key || '}')::text[], -- Путь для установки значения
                    _input -> absentPath -> key -- Установка значения из input
                );

                -- Объединение существующих глобальных значений с текущими значениями из _input
                absent_global := (
                    WITH data AS (
                        SELECT
                            (absent_global)::jsonb AS array1,
                            (_input -> absentPath -> key)::jsonb AS array2
                    ),
                    merged AS (
                        SELECT DISTINCT
                            jsonb_array_elements(array1) AS elem
                        FROM data
                        UNION
                        SELECT
                            jsonb_array_elements(array2)
                        FROM data
                    )
                    SELECT
                        jsonb_agg(elem) AS unique_merged_array
                    FROM merged
                );
            ELSE
                RAISE NOTICE 'Key doesn''t exist in list-input: %', key;
            END IF;
        END LOOP;

        -- Установка в объединенный финальный массив
        IF jsonb_array_length(absent_global) > 0 THEN
            class_body := jsonb_set(
                class_body,
                ('{' || absentPath || ', global}')::text[], -- Путь к глобальному значению
                absent_global
            );
			-- Установка absent.fstudents
			class_body := jsonb_set(
	            class_body,
	            ('{' || absentPath || ', fstudents}')::text[],
	            (
					SELECT COALESCE(jsonb_agg(absentStud), '[]'::jsonb)
					FROM jsonb_array_elements_text(class_body -> absentPath -> 'global') AS absentStud
					INNER JOIN jsonb_array_elements_text(class_body->'fstudents') AS fstud ON absentStud = fstud
				), -- Новое значение
	            true -- Перезаписать, если существует
	        );
        ELSE
            class_body := jsonb_set(
                class_body,
                ('{' || absentPath || ', global}')::text[],
                '[]'::jsonb -- Установка в null, если массив пуст
            );
			-- Установка absent.fstudents
			class_body := jsonb_set(
	            class_body,
	            ('{' || absentPath || ', fstudents}')::text[],
	            '[]'::jsonb
	        );
        END IF;

        -- Установка isClassDataFilled в true
        class_body := jsonb_set(
            class_body,
            '{isClassDataFilled}'::text[], -- Путь для установки isClassDataFilled
            'true'::jsonb, -- Новое значение
            true -- Перезаписать, если существует
        );
		RETURN class_body;
	-- RAISE NOTICE '[BODY]: %', class_body;
ELSE
	RAISE EXCEPTION 'Cannot read class_body for class: %. Does it exist?', _classID;
END IF;
END;
$$;


ALTER FUNCTION public._class_body_get(_schoolid uuid, _classid uuid, _input jsonb, _date date) OWNER TO postgres;

--
-- Name: _user_create(uuid, text, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public._user_create(IN _orgref uuid, IN _login text, IN _password text, IN _name text)
    LANGUAGE plpgsql
    AS $$
       DECLARE
           v_user_id UUID;
           v_salt TEXT;
       BEGIN
          v_user_id := uuid_generate_v4();
          -- Generate a random salt
          v_salt := gen_salt('bf');

          -- Insert user record into users table

          INSERT INTO public.users(id, login, password, school_id, name)
          VALUES(v_user_id, _login, crypt(_password, v_salt), _orgRef, _name);

     -- Insert the generated salt into user_salts table
          INSERT INTO public.users_salts(user_id, salt)
          VALUES(v_user_id, v_salt);

          UPDATE public.schools
              SET members = jsonb_set(
	              members,
	              ( '{' || v_user_id::text || '}' )::text[],
	              jsonb_build_object(
	                   'roles', ARRAY[]::text[],
	                   'classes', ARRAY[]::text[]
	              )::jsonb,
	              true
              )
WHERE id = _orgRef;
      END;
      $$;


ALTER PROCEDURE public._user_create(IN _orgref uuid, IN _login text, IN _password text, IN _name text) OWNER TO postgres;

--
-- Name: _user_drop(uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public._user_drop(IN _userref uuid)
    LANGUAGE plpgsql
    AS $$
DECLARE
        school_refs uuid[];
        school uuid;
BEGIN
	if (_userRef is null) then
		return;
	end if;

        SELECT array_agg(DISTINCT school_id) INTO school_refs
		  FROM users
		  WHERE id = _userRef;
		  
        FOREACH school in array school_refs LOOP
        update schools_classes_ownership set user_id = uuid_nil()
                where school_id = school
                and user_id = _userRef;
        END LOOP;
        delete from users_salts where user_id = _userRef;
        delete from users where id = _userRef;
		delete from schools_users where user_id = _userRef;
		delete from schools_classes_ownership where user_id = _userRef;
END;
$$;


ALTER PROCEDURE public._user_drop(IN _userref uuid) OWNER TO postgres;

--
-- Name: class_create(uuid, uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_create(IN _orgref uuid, IN _teacherref uuid, IN _class_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
template_class_body jsonb;
virt_class_id uuid;
BEGIN	
		select template_body into template_class_body from schools_template_classes
			WHERE school_id = _orgRef;
		template_class_body := jsonb_set(
			template_class_body,
			'{name}'::text[],
			to_jsonb(_class_name)
		);

		virt_class_id := uuid_generate_v4();
		
		insert into schools_classes(school_id, class_id, class_body) VALUES (
			_orgRef,
			virt_class_id,
			template_class_body
		);
		
		IF (_teacherref IS NOT NULL) THEN
			insert into schools_classes_ownership(school_id, user_id, class_id) values (
			_orgRef,
			_teacherref,
			virt_class_id
			);
		END IF;
		
END;
$$;


ALTER PROCEDURE public.class_create(IN _orgref uuid, IN _teacherref uuid, IN _class_name text) OWNER TO postgres;

--
-- Name: class_data_get(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_data_get(_schoolid uuid, _classid uuid, _date date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$

DECLARE
	data_root jsonb;
BEGIN
		
	if (_date is null) then
		_date := current_date;
	end if;
	
	if (select exists(select 1 from schools_data where schools_data.school_id = _schoolID and schools_data.date = _date)) then
		select schools_data.data->_classID::text into data_root
		from schools_data
		where school_id = _schoolID and date = _date;

		return jsonb_build_object(
			'absent', data_root->'absent',
			'students', data_root->'students',
			'fstudents', data_root->'fstudents',
			'isClassDataFilled', data_root->'isClassDataFilled'
		);
	else
		return 	jsonb_build_object('absent', null);
END if;
END;
$$;


ALTER FUNCTION public.class_data_get(_schoolid uuid, _classid uuid, _date date) OWNER TO postgres;

--
-- Name: class_data_insert(uuid, uuid, jsonb, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb, IN _date date)
    LANGUAGE plpgsql
    AS $$
DECLARE
    class_body jsonb;
BEGIN
	IF (_date = current_date) THEN
		call school_data_gen(_schoolid);
	END IF;

    IF NOT EXISTS
			(SELECT 1 FROM schools_data
        		WHERE school_id = _schoolID
        		AND date = _date
			) THEN
		RAISE NOTICE 'Data is not exists';
		RETURN;
    END IF;

	IF (_date is not null) then
		class_body := _class_body_get(_schoolid, _classid, _input, _date);
	ELSE
		RAISE EXCEPTION 'field "date" is null. Aborting';
	END IF;

	-- УСТАНОВКА В ТАБЛИЦУ
	UPDATE schools_data SET data = jsonb_set(
		data,
		('{'::text || _classID::text || '}'::text)::text[],
		class_body
	)
	WHERE school_id = _schoolID
	AND date = _date;

END;$$;


ALTER PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb, IN _date date) OWNER TO postgres;

--
-- Name: class_drop(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_drop(IN _orgref uuid, IN _class_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes where school_id = _orgRef AND class_id = _class_id) THEN
		DELETE from schools_classes_ownership where school_id = _orgRef AND class_id = _class_id;
		DELETE from schools_classes where school_id = _orgRef AND class_id = _class_id;
	END IF;
END;
$$;


ALTER PROCEDURE public.class_drop(IN _orgref uuid, IN _class_id uuid) OWNER TO postgres;

--
-- Name: class_props_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_props_get(_orgid uuid, _classid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
    return (select class_body - 'absent' from schools_classes
            where school_id = _orgID
              and class_id = _classID);
end;
$$;


ALTER FUNCTION public.class_props_get(_orgid uuid, _classid uuid) OWNER TO postgres;

--
-- Name: class_rename(uuid, uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_rename(IN _orgref uuid, IN _class_id uuid, IN _new_classname text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools_classes 
			where school_id = _orgRef 
			and class_id = _class_id
	) THEN
		update schools_classes set class_body = jsonb_set(
		class_body,
		'{name}'::text[],
		to_jsonb(_new_classname::text)
		) 
			where school_id = _orgRef 
			and class_id = _class_id;
	ELSE	
		raise notice 'Not found class_id: % for org: %', _class_id, _orgref;
	END IF;
END;
$$;


ALTER PROCEDURE public.class_rename(IN _orgref uuid, IN _class_id uuid, IN _new_classname text) OWNER TO postgres;

--
-- Name: class_students_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_students_get(_school_id uuid, _class_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
		return (select jsonb_build_object(
			'students', class_body->'students',
			'fstudents', class_body->'fstudents'
		) from schools_classes 
			where school_id = _school_id
			and class_id = _class_id
		);
end;
$$;


ALTER FUNCTION public.class_students_get(_school_id uuid, _class_id uuid) OWNER TO postgres;

--
-- Name: class_students_set(uuid, uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_set(IN _orgref uuid, IN _classref uuid, IN _studentstree jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes
		where school_id = _orgRef
		AND class_id = _classRef)
	THEN
		update schools_classes set class_body = jsonb_set(
			jsonb_set(
				class_body::jsonb,
				'{students}'::text[],
				_studentsTree->'students',
				true
			)::jsonb,
			'{fstudents}'::text[],
			_studentsTree->'fstudents',
			true
		) 
		where school_id = _orgRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, class: %',
			_orgRef,
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_students_set(IN _orgref uuid, IN _classref uuid, IN _studentstree jsonb) OWNER TO postgres;

--
-- Name: deep_merge_json_objects(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.deep_merge_json_objects(jsonb, jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  merged jsonb := $1;
  key text;
  value jsonb;
  array_element jsonb;
BEGIN
  FOR key, value IN SELECT * FROM jsonb_each($2)
  LOOP
    IF merged? key THEN
      IF jsonb_typeof(merged->key) = 'object' AND jsonb_typeof(value) = 'object' THEN
        merged := merged || jsonb_build_object(key, deep_merge_json_objects(merged->key, value));
      ELSIF jsonb_typeof(merged->key) = 'array' AND jsonb_typeof(value) = 'array' THEN
        FOR array_element IN SELECT * FROM jsonb_array_elements(value)
        LOOP
          merged := merged || jsonb_build_object(key, merged->key || array_element);
        END LOOP;
      ELSE
        merged := merged || jsonb_build_object(key, value);
      END IF;
    ELSE
      merged := merged || jsonb_build_object(key, value);
    END IF;
  END LOOP;
  RETURN merged;
END;
$_$;


ALTER FUNCTION public.deep_merge_json_objects(jsonb, jsonb) OWNER TO postgres;

--
-- Name: is_class_exists(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_class_exists(_school uuid, _class uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (_class is null) then
		return false;
	end if;

	if (select 1 from schools_classes where
		school_id = _school 
		AND class_id = _class
	) THEN return true;
	end if;
	return false;
END;
$$;


ALTER FUNCTION public.is_class_exists(_school uuid, _class uuid) OWNER TO postgres;

--
-- Name: is_class_owned(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_class_owned(_school uuid, _user uuid, _class uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools_classes_ownership where
		school_id = _school 
		AND user_id = _user
		AND class_id = _class
	) THEN return true;
	end if;
	return false;
END;
$$;


ALTER FUNCTION public.is_class_owned(_school uuid, _user uuid, _class uuid) OWNER TO postgres;

--
-- Name: is_custom_org_data_exists(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_custom_org_data_exists(_orgref uuid, _date date) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_data WHERE school_id = _orgRef AND date = _date) THEN
		RETURN TRUE;
	END IF;
RETURN FALSE;
END
$$;


ALTER FUNCTION public.is_custom_org_data_exists(_orgref uuid, _date date) OWNER TO postgres;

--
-- Name: is_date(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_date(s character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
  perform s::date;
  return true;
exception when others then
  return false;
end;
$$;


ALTER FUNCTION public.is_date(s character varying) OWNER TO postgres;

--
-- Name: is_invite_exists(uuid, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_invite_exists(_schoolid uuid, _reqid character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	return (select exists(select 1 from schools_invites 
		where school_id = _schoolID
		and req_id = _reqID));
end;
$$;


ALTER FUNCTION public.is_invite_exists(_schoolid uuid, _reqid character varying) OWNER TO postgres;

--
-- Name: is_invite_valid(uuid, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_invite_valid(_school_id uuid, _req_id character varying, _req_secret character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
begin
	if (select exists (select 1 from schools_invites 
			where school_id = _school_id
			and req_id = _req_id
			and req_secret = _req_secret)) then
		return true;
	end if;
	return false;
end;
$$;


ALTER FUNCTION public.is_invite_valid(_school_id uuid, _req_id character varying, _req_secret character varying) OWNER TO postgres;

--
-- Name: is_school_data_exists(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_school_data_exists(_orgref uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_data WHERE school_id = _orgRef AND date = CURRENT_DATE) THEN
		RETURN TRUE;
	END IF;
RETURN FALSE;
END
$$;


ALTER FUNCTION public.is_school_data_exists(_orgref uuid) OWNER TO postgres;

--
-- Name: is_school_data_exists(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_school_data_exists(_orgref uuid, _date date) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (_date = null) THEN
		_date = CURRENT_DATE;
	END IF;
	
	IF (select 1 from schools_data WHERE school_id = _orgRef AND date = _date) THEN
		RETURN TRUE;
	END IF;
RETURN FALSE;
END
$$;


ALTER FUNCTION public.is_school_data_exists(_orgref uuid, _date date) OWNER TO postgres;

--
-- Name: is_user_has_classes(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_user_has_classes(_schoolid uuid, _userid uuid) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools_classes_ownership where
		school_id = _schoolID
		AND user_id = _userID LIMIT 1
	) THEN return true;
	end if;
	return false;
END;
$$;


ALTER FUNCTION public.is_user_has_classes(_schoolid uuid, _userid uuid) OWNER TO postgres;

--
-- Name: is_user_has_role(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_user_has_role(_orgid uuid, _userid uuid, _role text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools_users 
			where school_id = _orgID 
			and user_id = _userID
			and _role = ANY(roles)) 
	THEN
		RETURN TRUE;
	END IF;
	RETURN FALSE;
END;
$$;


ALTER FUNCTION public.is_user_has_role(_orgid uuid, _userid uuid, _role text) OWNER TO postgres;

--
-- Name: is_valid_user(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_valid_user(p_login text, p_password text) RETURNS TABLE(valid boolean, userid uuid)
    LANGUAGE plpgsql
    AS $$
DECLARE 
	v_salt TEXT;
	v_stored_password TEXT;
BEGIN
SELECT salt INTO v_salt FROM public.users_salts

JOIN public.users AS us ON user_id = us.id WHERE us.login = p_login;

IF v_salt IS NULL THEN 
	RETURN QUERY SELECT FALSE, uuid_nil();
	RETURN;
END IF;

SELECT password INTO v_stored_password FROM public.users WHERE login = p_login;

IF v_stored_password IS NULL THEN 
	RETURN QUERY SELECT FALSE as valid, uuid_nil() as uuid; 
END IF;

IF crypt(p_password, v_salt) = v_stored_password THEN
	RETURN QUERY SELECT TRUE as valid, us.id as uuid
        FROM public.users AS us
        WHERE us.login = p_login;
ELSE
	RETURN QUERY SELECT FALSE as valid, uuid_nil() as uuid;
END IF; 
END;
$$;


ALTER FUNCTION public.is_valid_user(p_login text, p_password text) OWNER TO postgres;

--
-- Name: log_changes(uuid, uuid, text, text, text, uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.log_changes(IN _school_id uuid, IN _user_id uuid, IN _category text, IN _operation text, IN _changed_property text, IN _object_id uuid, IN _data jsonb)
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO schools_change_logs(school_id, user_id, category, operation, changed_property, object_id, row_data)
        VALUES (_school_id,
                _user_id,
                _category,
                _operation,
                _changed_property,
                _object_id,
                _data);
    END;
    $$;


ALTER PROCEDURE public.log_changes(IN _school_id uuid, IN _user_id uuid, IN _category text, IN _operation text, IN _changed_property text, IN _object_id uuid, IN _data jsonb) OWNER TO postgres;

--
-- Name: merge_jsonb_arrays(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.merge_jsonb_arrays(p_jsonb jsonb, p_new jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  IF p_jsonb IS NULL THEN
    RETURN p_new;
  ELSIF p_new IS NULL THEN
    RETURN p_jsonb;
  ELSE
    RETURN p_jsonb || p_new;
  END IF;
END;
$$;


ALTER FUNCTION public.merge_jsonb_arrays(p_jsonb jsonb, p_new jsonb) OWNER TO postgres;

--
-- Name: null_to_array(text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.null_to_array(_array text[]) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (_array is null) then
		return '{}'::text[];
	END IF;
	return _array;
END;
$$;


ALTER FUNCTION public.null_to_array(_array text[]) OWNER TO postgres;

--
-- Name: school_class_body_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_class_body_get(_orgref uuid, _classid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
    DECLARE
        data jsonb;
    BEGIN
        WITH ownership_data AS (
            SELECT jsonb_agg(
                           jsonb_build_object(
                                   'id', ownership.user_id,
                                   'name', (SELECT name FROM users WHERE school_id = _orgref AND id = ownership.user_id)
                           )
                   ) AS owners
            FROM schools_classes_ownership ownership
            WHERE ownership.class_id = _classid
              AND ownership.school_id = _orgref
        )
        SELECT jsonb_set((select class_body - 'absent' from schools_classes where school_id = _orgref and class_id = _classid),
                         '{owners}',
                         COALESCE((SELECT owners FROM ownership_data), '[]'::jsonb))
        INTO data; -- Set owners into class body, default to empty array
        RETURN data;
    END;
    $$;


ALTER FUNCTION public.school_class_body_get(_orgref uuid, _classid uuid) OWNER TO postgres;

--
-- Name: school_class_owners_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_class_owners_get(_orgref uuid, _classid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
    BEGIN
        return COALESCE( jsonb_agg(
                           jsonb_build_object(
                                   'id', ownership.user_id,
                                   'name', (SELECT name FROM users WHERE school_id = _orgref AND id = ownership.user_id)
                           )
                   ), '[]'::jsonb)
            FROM (select user_id FROM schools_classes_ownership
            WHERE class_id = _classid AND school_id = _orgref) as ownership;

    end;
    $$;


ALTER FUNCTION public.school_class_owners_get(_orgref uuid, _classid uuid) OWNER TO postgres;

--
-- Name: school_class_users_set(uuid, uuid, uuid[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_class_users_set(IN _schoolref uuid, IN _classid uuid, IN _userrefs uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Remove classes that are not in the new class_ids
    DELETE
    FROM schools_classes_ownership
    WHERE school_id = _schoolref
      AND class_id = _classid
      AND user_id NOT IN (SELECT unnest(_userrefs) AS user_id);

    -- Insert classes that are in the new class_ids
    INSERT INTO schools_classes_ownership(school_id, class_id, user_id)
    SELECT _schoolref, _classid, user_id
    FROM (SELECT unnest(_userrefs) AS user_id) AS user_ids
    WHERE user_id NOT IN (SELECT user_id
                           FROM schools_classes_ownership
                           WHERE school_id = _schoolref
                             AND class_id = _classid);

END;
$$;


ALTER PROCEDURE public.school_class_users_set(IN _schoolref uuid, IN _classid uuid, IN _userrefs uuid[]) OWNER TO postgres;

--
-- Name: school_classes_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_classes_get(_orgid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT 1 FROM schools WHERE id = _orgID) THEN
        RETURN (
            SELECT
                jsonb_agg(jsonb_build_object(
					'id', sch_classes.class_id,
                    'name', sch_classes.class_body->'name',
                    'students', sch_classes.class_body->'students',
                    'fstudents', sch_classes.class_body->'fstudents',
                    'owners', (
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', user_id,
                                'name', (SELECT name FROM users WHERE id = ownerships.user_id AND school_id = _orgID)
                            )
                        )
                        FROM schools_classes_ownership ownerships
                        WHERE ownerships.class_id = sch_classes.class_id AND school_id = _orgID
                    )
                )) AS class_details
            FROM schools_classes AS sch_classes
            WHERE school_id = _orgID
        );
    END IF;
END;
$$;


ALTER FUNCTION public.school_classes_get(_orgid uuid) OWNER TO postgres;

--
-- Name: school_data_custom_gen(uuid, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_data_custom_gen(IN _orgref uuid, IN _date date)
    LANGUAGE plpgsql
    AS $$
DECLARE
	rec RECORD;
    root_new_data jsonb := '{}';
BEGIN
	IF (select exists(select 1 from schools_data where school_id = _orgRef AND date = _date)) THEN
		RAISE NOTICE 'DATA IS ALREADY EXISTS';
	ELSE -- Data isnt exists
		-- Iterating through all classes
		FOR rec IN
			select class_name, class_body from schools_classes
			where school_id = _orgRef
		LOOP -- Inserting into root all classes
			root_new_data := jsonb_insert(
				root_new_data, 
				('{' || rec.class_name || '}')::text[], 
				jsonb_set(rec.class_body,
					'{owner}'::text[],
					jsonb_build_object(
					'id', rec.user_id,
					'name', (select name from users where school_id = _orgRef and id = rec.user_id)
					)
				)
			);

		END LOOP;
		-- Inserting into schools_data table 'root_new_data'
		INSERT INTO public.schools_data(school_id, date, data) VALUES (
			_orgRef,
			_date,
			root_new_data
		);
END IF;

END;
$$;


ALTER PROCEDURE public.school_data_custom_gen(IN _orgref uuid, IN _date date) OWNER TO postgres;

--
-- Name: school_data_gen(uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_data_gen(IN _orgref uuid)
    LANGUAGE plpgsql
    AS $$DECLARE
    rec RECORD;
    root_new_data JSONB := '{}';
BEGIN
    -- Check if the data already exists
    IF (SELECT true FROM schools_data 
        WHERE school_id = _orgref 
        AND date = CURRENT_DATE) 
    THEN
        RAISE NOTICE 'DATA ALREADY EXISTS';
    ELSE
        -- Iterating through all classes
        FOR rec IN
            SELECT classes.class_id, classes.class_body
            FROM schools_classes classes
            LEFT JOIN schools_classes_ownership_view view
                ON classes.school_id = view.school_id AND classes.class_id = view.class_id
            WHERE classes.school_id = _orgref
            GROUP BY classes.class_id, classes.class_body
        LOOP
            RAISE NOTICE 'class_name: %', rec.class_body->>'name';

            -- Build a JSONB array of owners for the current class
            WITH ownership_data AS (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', ownership.user_id,
                        'name', (SELECT name FROM users WHERE school_id = _orgref AND id = ownership.user_id)
                    )
                ) AS owners
                FROM schools_classes_ownership ownership
                WHERE ownership.class_id = rec.class_id AND ownership.school_id = _orgref
            )
            -- Check if owners exist before attempting to set them
            SELECT jsonb_insert(
                root_new_data,
                ('{' || rec.class_id || '}')::text[],  -- Path to insert new data
                jsonb_set(rec.class_body, '{owners}', COALESCE((SELECT owners FROM ownership_data), '[]'::jsonb))  -- Set owners into class body, default to empty array
            ) INTO root_new_data;  -- Insert the new root data into the variable

            -- Insert isActualData for the current class
            root_new_data := jsonb_set(
                root_new_data,
                ('{' || rec.class_id || '}')::text[],  -- Path to the class ID
                jsonb_set(
                    root_new_data->rec.class_id::text,  -- Get the existing class data
                    '{isClassDataFilled}'::text[],  -- Path for new property
                    'false'::jsonb  -- New value for the property
                )
            );
        END LOOP;

        -- Insert the new data into schools_data
        INSERT INTO schools_data(school_id, date, data)
        VALUES (_orgref, CURRENT_DATE, root_new_data);
    END IF;
END;$$;


ALTER PROCEDURE public.school_data_gen(IN _orgref uuid) OWNER TO postgres;

--
-- Name: school_data_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_data_get(_orgid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT EXISTS 
		(SELECT 1 FROM schools_data 
			WHERE school_id = _orgID 
			AND date = CURRENT_DATE)) THEN
        RETURN (
            SELECT
                data
            FROM
                schools_data
            WHERE
                school_id = _orgID
                AND DATE = CURRENT_DATE
        );
    END IF;
	return null::jsonb;
END;$$;


ALTER FUNCTION public.school_data_get(_orgid uuid) OWNER TO postgres;

--
-- Name: school_data_get(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_data_get(_orgid uuid, _date date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN

IF (_date is null) THEN
        _date := CURRENT_DATE;
END IF;
if (select true from schools_data where school_id = _orgID and date = _date) THEN
        return (
			select data
				FROM schools_data
				WHERE school_id = _orgID
				AND date = _date
			);
END IF;
	return null::jsonb;
END;
$$;


ALTER FUNCTION public.school_data_get(_orgid uuid, _date date) OWNER TO postgres;

--
-- Name: school_data_summarized_get(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_data_summarized_get(_orgid uuid, _dates jsonb) RETURNS TABLE(class_id text, class_body jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    start_date date;
    end_date date;
    result jsonb;
BEGIN
    -- Extract start and end date from the input JSONB
    start_date := (_dates->>'start_date')::date;
    end_date := (_dates->>'end_date')::date;

    -- Initialize the result
    result := '{}'::jsonb;

    -- Aggregate the data
    WITH summed_amounts AS (
        SELECT
            key,
            value->'name' as class_name,
            (value->>'amount')::integer AS total_amount,
            value->'absent' AS absent_list,
            value->'students' as students,
            value->'owners' as owners
        FROM
            schools_data,
            jsonb_each(data) AS elements(key, value)
        WHERE
            school_id = _orgID and date between start_date and end_date
    ),
    absent_elements AS (
        SELECT
            sa.key, --id
            ae.k, --cause type
            jae.e as v -- cause array
        FROM
            summed_amounts as sa
            JOIN jsonb_each(sa.absent_list) AS ae(k, v) ON TRUE
            LEFT JOIN jsonb_array_elements_text(v) AS jae(e) ON TRUE
    ),
    merged_absent AS (
        SELECT
            key,
            k,
            jsonb_agg(v ORDER BY v) AS v
        FROM
            absent_elements
        WHERE
            v IS NOT NULL
        GROUP BY key, k
    ),
    final_absent AS (
        SELECT
            key,
            jsonb_object_agg(k, COALESCE(v, '[]'::jsonb)) AS absent
        FROM
            (
                SELECT
                    key,
                    k,
                    v
                FROM
                    merged_absent
                UNION ALL
                SELECT
                    sa.key,
                    k,
                    '[]'::jsonb
                FROM
                    summed_amounts sa
                CROSS JOIN
                    jsonb_each(sa.absent_list) AS ae(k, v)
                WHERE
                    (sa.key, ae.k) NOT IN (SELECT key, k FROM merged_absent)
            ) AS subquery
        GROUP BY key
    )
    SELECT
        jsonb_object_agg(s.key, jsonb_build_object(
            'name', s.class_name,
            'amount', s.total_amount,
            'absent', fa.absent,
           'students', s.students,
            'owners', s.owners
        )) into result
    FROM
        summed_amounts s
        JOIN final_absent fa ON s.key = fa.key;
    RETURN query (select key, value from jsonb_each(result));
END;
$$;


ALTER FUNCTION public.school_data_summarized_get(_orgid uuid, _dates jsonb) OWNER TO postgres;

--
-- Name: school_id_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_id_get(_userid uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$

BEGIN
	return (select school_id from users where id = _userid);
END;

$$;


ALTER FUNCTION public.school_id_get(_userid uuid) OWNER TO postgres;

--
-- Name: school_invite_archive(uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_invite_archive(IN _orgid uuid, IN _reqid text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	WITH moved_invites AS (
	  DELETE FROM schools_invites
	  WHERE req_id = _reqID
	  RETURNING school_id,
	  	req_id, 
	  	req_secret, 
	  	req_body
	)
	INSERT INTO schools_invites_archived (
		school_id, 
		req_id, 
		req_secret,
		req_body,
		use_time)
	SELECT school_id,
		req_id, 
		req_secret, 
		req_body,
		NOW()
	FROM moved_invites;
END;
$$;


ALTER PROCEDURE public.school_invite_archive(IN _orgid uuid, IN _reqid text) OWNER TO postgres;

--
-- Name: school_invite_create(uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_invite_create(IN _school_id uuid, IN _req_body jsonb)
    LANGUAGE plpgsql
    AS $$DECLARE
    num int;
BEGIN

    INSERT INTO public.schools_invites(
        school_id, 
        req_id, 
        req_secret, 
        req_body -- Assuming invite_data is the column where you want to store the jsonb data
    ) VALUES (
        _school_id,
        school_invite_req_id_gen(_school_id),
        floor(random() * 10000),
        jsonb_build_object(
            'name', _req_body->'name',
            'roles', _req_body->'roles',
            'classes', (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'id', u_class_id,
                            'name', (
                                SELECT class_body->>'name' 
                                FROM schools_classes
                                WHERE school_id = _school_id
                                AND class_id = u_class_id::uuid  -- Ensure you have the correct type for class_id
                            )
                        )
                    ),
                    '[]'::jsonb  -- Return an empty array if the result is NULL
                )
                FROM jsonb_array_elements_text(_req_body->'classes') AS u_class_id
            )
        )
    );
END;$$;


ALTER PROCEDURE public.school_invite_create(IN _school_id uuid, IN _req_body jsonb) OWNER TO postgres;

--
-- Name: school_invite_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_invite_get(_orgref uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
	return (
		select jsonb_agg(
			jsonb_build_object(
				'id', req_id,
				'secret', req_secret,
				'body', req_body
			)
		)
		from schools_invites
		where school_id = _orgref
	);
end;
$$;


ALTER FUNCTION public.school_invite_get(_orgref uuid) OWNER TO postgres;

--
-- Name: school_invite_props_get(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_invite_props_get(_orgref uuid, _req_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$begin
    if (select exists (select 1 from schools_invites
                       where school_id = _orgref
                         and req_id = _req_id)) then
        return req_body from schools_invites
            where school_id = _orgref
            and req_id = _req_id;
    end if;
    return null;
end;$$;


ALTER FUNCTION public.school_invite_props_get(_orgref uuid, _req_id text) OWNER TO postgres;

--
-- Name: school_invite_req_id_gen(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_invite_req_id_gen(_school_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
    unique_id TEXT;
BEGIN
    unique_id := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    RETURN unique_id;
END;$$;


ALTER FUNCTION public.school_invite_req_id_gen(_school_id uuid) OWNER TO postgres;

--
-- Name: school_logs_get(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_logs_get(_orgref uuid, _date date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
    return (
        select jsonb_agg(
                       jsonb_build_object(
                               'id', id,
                               'user', jsonb_build_object(
                                       'name', (select name from users where school_id = _orgref and users.id = user_id),
                                       'id', user_id
                                       ),
                               'context', jsonb_build_object(
                                       'category', category,
                                       'operation', operation,
                                       'changed_property', changed_property
                                          ),
                               'changed_at', jsonb_build_object(
                                       'time', changed_at::time(0),
                                       'date', changed_at::date
                                             ),
                               'object_id', object_id,
                               'log_data', row_data
                       )
               )
        from schools_change_logs
        where school_id = _orgref
        and changed_at::date = _date
    );
end;
$$;


ALTER FUNCTION public.school_logs_get(_orgref uuid, _date date) OWNER TO postgres;

--
-- Name: school_logs_period_get(uuid, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_logs_period_get(_orgref uuid, _datestart date, _dateend date) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
    return (
        select jsonb_agg(
                       jsonb_build_object(
                               'id', id,
                               'user', jsonb_build_object(
                                       'name', (select name from users where school_id = _orgref and users.id = user_id),
                                       'id', user_id
                                       ),
                               'context', jsonb_build_object(
                                       'category', category,
                                       'operation', operation,
                                       'changed_property', changed_property
                                   ),
                               'changed_at', jsonb_build_object(
                                       'time', changed_at::time(0),
                                       'date', changed_at::date
                                             ),
                               'object_id', object_id,
                               'log_data', row_data
                       )
               )
        from schools_change_logs
        where school_id = _orgref
          and changed_at::date between _dateStart and _dateEnd
    );
end;
$$;


ALTER FUNCTION public.school_logs_period_get(_orgref uuid, _datestart date, _dateend date) OWNER TO postgres;

--
-- Name: school_org_data_get(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_org_data_get(_orgid text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (_orgID IS NULL) THEN
		return null;
	END IF;
	
	return (
		select 
			jsonb_build_object(
				'title', title,
				'city', city,
				'email', email
			)
		from schools where id::text = _orgID
		);
END;
$$;


ALTER FUNCTION public.school_org_data_get(_orgid text) OWNER TO postgres;

--
-- Name: school_req_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_req_get(_school_id uuid) RETURNS TABLE(req_id character varying, req_secret character varying, req_body jsonb)
    LANGUAGE plpgsql
    AS $$
begin
	return query(select si.req_id, si.req_secret, si.req_body from schools_invites si where school_id = _school_id);
end;
$$;


ALTER FUNCTION public.school_req_get(_school_id uuid) OWNER TO postgres;

--
-- Name: school_user_body_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_user_body_get(_orgref uuid, _userid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    data jsonb;
BEGIN
    WITH ownership_data AS (
        SELECT jsonb_agg(
                       jsonb_build_object(
                               'id', ownership.class_id,
                               'name', (SELECT class_body->'name' FROM schools_classes WHERE school_id = _orgref AND class_id = ownership.class_id)
                       )
               ) AS owners
        FROM schools_classes_ownership ownership
        WHERE ownership.user_id = _userid
          AND ownership.school_id = _orgref
    ) select jsonb_build_object('name', t.name,
             'roles', t.roles,
             'classes', COALESCE(t.owners, '[]'::jsonb)
             ) from (select
        name, roles, owners from users u, schools_users su, ownership_data where u.school_id = _orgref and u.id = _userid
                                                                          and su.school_id = _orgref and su.user_id = _userid) as t
    INTO data;
    return data;
END;
$$;


ALTER FUNCTION public.school_user_body_get(_orgref uuid, _userid uuid) OWNER TO postgres;

--
-- Name: school_user_classes_set(uuid, uuid, uuid[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_user_classes_set(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[])
    LANGUAGE plpgsql
    AS $$BEGIN
    -- Remove classes that are not in the new class_ids
    DELETE FROM schools_classes_ownership
    WHERE school_id = _schoolref
      AND user_id = _userid
      AND class_id NOT IN (
          SELECT unnest(_classrefs) AS class_id
      );

    -- Insert classes that are in the new class_ids
    INSERT INTO schools_classes_ownership(school_id, user_id, class_id)
    SELECT _schoolref, _userid, class_id
    FROM (
        SELECT unnest(_classrefs) AS class_id
    ) AS class_ids
    WHERE class_id NOT IN (
        SELECT class_id
        FROM schools_classes_ownership
        WHERE school_id = _schoolref
          AND user_id = _userid
    );

END;$$;


ALTER PROCEDURE public.school_user_classes_set(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[]) OWNER TO postgres;

--
-- Name: school_user_drop(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_user_drop(IN _orgid uuid, IN _userid uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN

	if (_userid is null) then
		return;
	end if;

        delete from users_salts 
			where user_id = _userID;
        delete from users where id = _userID;
		delete from schools_users where user_id = _userID;
		delete from schools_classes_ownership where user_id = _userID;
END;
$$;


ALTER PROCEDURE public.school_user_drop(IN _orgid uuid, IN _userid uuid) OWNER TO postgres;

--
-- Name: school_user_name_set(uuid, uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_user_name_set(IN _schoolid uuid, IN _userid uuid, IN _username text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the user's name in the users table
    UPDATE users
    SET name = _userName
    WHERE school_id = _schoolID
      AND id = _userID;

    -- Check if the update was successful
    IF NOT FOUND THEN
        RAISE NOTICE 'No user found with school_id = % and id = %', _schoolID, _userID;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$;


ALTER PROCEDURE public.school_user_name_set(IN _schoolid uuid, IN _userid uuid, IN _username text) OWNER TO postgres;

--
-- Name: school_user_password_reset(uuid, uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_user_password_reset(IN _schoolid uuid, IN _userid uuid, IN _newpassword text)
    LANGUAGE plpgsql
    AS $$
declare
	v_salt text;
begin
	v_salt := gen_salt('bf');
	
	update users set password = crypt(_newPassword, v_salt)
		where school_id = _schoolID
		and id = _userID;
	update users_salts set salt = v_salt
		where user_id = _userID;
end;
$$;


ALTER PROCEDURE public.school_user_password_reset(IN _schoolid uuid, IN _userid uuid, IN _newpassword text) OWNER TO postgres;

--
-- Name: school_users_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_users_get(_orgid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN
	jsonb_agg(
        jsonb_build_object(
			'id', users.id::text,
            'name', users.name::text,
            'roles', schools_users.roles, -- Include roles
            'classes', COALESCE(class_info.classes, '[]'::jsonb) -- Include classes, default to empty array if null
        )) AS user_info
    FROM
        users
    JOIN
        schools_users 
		ON users.id = schools_users.user_id::uuid
		AND users.school_id = schools_users.school_id
    LEFT JOIN (
        SELECT
            class_data.user_id,
            jsonb_agg(jsonb_build_object( -- Create an array of JSON objects
                'id', class_data.class_id,
                'name', class_data.class_name
            )) AS classes  -- Aggregate classes into a JSON array
        FROM (
            SELECT
                view.user_id,
                view.class_id,
                view.class_body ->> 'name' AS class_name
            FROM
                schools_classes_ownership_view view
        ) AS class_data
        GROUP BY
            class_data.user_id  -- Group by user_id
    ) AS class_info ON class_info.user_id = users.id
    WHERE
        schools_users.school_id = _orgID;  -- Filter based on the organization ID
END;
$$;


ALTER FUNCTION public.school_users_get(_orgid uuid) OWNER TO postgres;

--
-- Name: user_classes_drop(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_classes_drop(IN _schoolref uuid, IN _userid uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN

update schools_classes
	set user_id = null
		where school_id = _schoolRef
		and user_id = _userID;
END;
$$;


ALTER PROCEDURE public.user_classes_drop(IN _schoolref uuid, IN _userid uuid) OWNER TO postgres;

--
-- Name: user_classes_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_classes_get(_orgref uuid, _teacherref uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN
        (
            select COALESCE(jsonb_agg(
                           jsonb_build_object(
                                   'id', classes.class_id,
                                   'name', classes.class_body->'name'
                           )), '[]'::jsonb)
            from schools_classes_ownership_view as classes
            where school_id = _orgref
              and user_id = _teacherref
        );
END;
$$;


ALTER FUNCTION public.user_classes_get(_orgref uuid, _teacherref uuid) OWNER TO postgres;

--
-- Name: user_create_with_context(uuid, text, text, text, text[], text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_create_with_context(IN _orgref uuid, IN _login text, IN _password text, IN _name text, IN _roles text[], IN _classes text[])
    LANGUAGE plpgsql
    AS $$
       DECLARE
           v_user_id UUID;
           v_salt TEXT;
       BEGIN
          v_user_id := uuid_generate_v4();
          -- Generate a random salt
          v_salt := gen_salt('bf');

          -- Insert user record into users table
          INSERT INTO public.users(id, login, password, school_id, name)
          VALUES(v_user_id, _login, crypt(_password, v_salt), _orgRef, _name);

     -- Insert the generated salt into user_salts table
          INSERT INTO public.users_salts(user_id, salt)
          VALUES(v_user_id, v_salt);
	
	
	
     -- Insert user's data in schools(members)
     IF (select 1 from public.users where school_id = _orgRef and id = v_user_id) THEN
	
	-- Insert roles and user member into school
	INSERT INTO schools_users(school_id, user_id, roles)
		SELECT _orgRef, v_user_id, _roles;
		
	
	WITH class_ids AS (
    	SELECT unnest(_classes) AS class_id
	),
	valid_class_ids AS (
    	SELECT class_id 
    	FROM class_ids
    	WHERE class_id IN (SELECT class_id::text FROM schools_classes WHERE school_id = _orgRef)
	)
	INSERT INTO schools_classes_ownership(school_id, user_id, class_id)
		SELECT _orgRef, v_user_id, class_id::uuid 
		FROM valid_class_ids;
ELSE
        RAISE notice 'no such user! %', _userID;
END IF;
      END;
      $$;


ALTER PROCEDURE public.user_create_with_context(IN _orgref uuid, IN _login text, IN _password text, IN _name text, IN _roles text[], IN _classes text[]) OWNER TO postgres;

--
-- Name: user_insert_in_school(uuid, uuid, text[], text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_insert_in_school(IN _orgref uuid, IN _userid uuid, IN _roles text[], IN _classes text[])
    LANGUAGE plpgsql
    AS $$
BEGIN

-- Insert user's data in schools(members)
IF (select 1 from public.users where school_id = _orgRef and id = _userID) THEN
UPDATE public.schools SET members = jsonb_set(
	members,
	( '{' || _userid::text || '}' )::text[],
	jsonb_build_object(
		'roles', _roles,
		'classes', _classes
	)::jsonb,
	true
)
WHERE id = _orgRef;
ELSE
	RAISE info 'no such user! %', _userID;
END IF;
END;
$$;


ALTER PROCEDURE public.user_insert_in_school(IN _orgref uuid, IN _userid uuid, IN _roles text[], IN _classes text[]) OWNER TO postgres;

--
-- Name: user_roles_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_roles_get(_schoolref uuid, _userid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN

    RETURN array_to_json(roles)::jsonb
	    FROM schools_users as su
        WHERE su.school_id = _schoolRef AND su.user_id = _userID;

END;

$$;


ALTER FUNCTION public.user_roles_get(_schoolref uuid, _userid uuid) OWNER TO postgres;

--
-- Name: user_roles_set(uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_roles_set(IN _orgref uuid, IN _userid uuid, IN _roles text[])
    LANGUAGE plpgsql
    AS $$
       BEGIN
		  UPDATE public.schools_users set roles = _roles
		  	WHERE school_id = _orgRef
			  AND user_id = _userID;
      END;
      $$;


ALTER PROCEDURE public.user_roles_set(IN _orgref uuid, IN _userid uuid, IN _roles text[]) OWNER TO postgres;

--
-- Name: uuid_or_null(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.uuid_or_null(str text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN str::uuid;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN uuid_nil();
END;
$$;


ALTER FUNCTION public.uuid_or_null(str text) OWNER TO postgres;

--
-- Name: merge_jsonb_arrays(jsonb); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.merge_jsonb_arrays(jsonb) (
    SFUNC = public.merge_jsonb_arrays,
    STYPE = jsonb
);


ALTER AGGREGATE public.merge_jsonb_arrays(jsonb) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: schools; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    region text NOT NULL,
    city text NOT NULL,
    area text NOT NULL,
    email text NOT NULL,
    members jsonb
);


ALTER TABLE public.schools OWNER TO postgres;

--
-- Name: schools_change_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_change_logs (
    id integer NOT NULL,
    school_id uuid NOT NULL,
    user_id uuid NOT NULL,
    category text NOT NULL,
    operation text NOT NULL,
    changed_property text,
    object_id uuid,
    changed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    row_data jsonb
);


ALTER TABLE public.schools_change_logs OWNER TO postgres;

--
-- Name: schools_change_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.schools_change_logs ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.schools_change_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schools_classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_classes (
    school_id uuid NOT NULL,
    class_id uuid NOT NULL,
    class_body jsonb
);


ALTER TABLE public.schools_classes OWNER TO postgres;

--
-- Name: schools_classes_ownership; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_classes_ownership (
    school_id uuid NOT NULL,
    user_id uuid NOT NULL,
    class_id uuid NOT NULL
);


ALTER TABLE public.schools_classes_ownership OWNER TO postgres;

--
-- Name: schools_classes_ownership_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.schools_classes_ownership_view AS
 SELECT s.id AS school_id,
    o.user_id,
    c.class_id,
    c.class_body
   FROM ((public.schools_classes c
     JOIN public.schools s ON ((c.school_id = s.id)))
     JOIN public.schools_classes_ownership o ON (((c.school_id = o.school_id) AND (c.class_id = o.class_id))));


ALTER VIEW public.schools_classes_ownership_view OWNER TO postgres;

--
-- Name: schools_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_data (
    school_id uuid NOT NULL,
    date date NOT NULL,
    data jsonb
);


ALTER TABLE public.schools_data OWNER TO postgres;

--
-- Name: schools_invites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_invites (
    school_id uuid NOT NULL,
    req_id character varying(6) NOT NULL,
    req_secret character varying(6) NOT NULL,
    req_body jsonb
);


ALTER TABLE public.schools_invites OWNER TO postgres;

--
-- Name: schools_invites_archived; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_invites_archived (
    school_id uuid,
    req_id character varying(6),
    req_secret character varying(6),
    req_body jsonb,
    use_time timestamp without time zone
);


ALTER TABLE public.schools_invites_archived OWNER TO postgres;

--
-- Name: schools_template_classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_template_classes (
    school_id uuid NOT NULL,
    template_body jsonb DEFAULT '{"absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}'::jsonb NOT NULL
);


ALTER TABLE public.schools_template_classes OWNER TO postgres;

--
-- Name: schools_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_users (
    school_id uuid NOT NULL,
    user_id uuid NOT NULL,
    roles text[] NOT NULL
);


ALTER TABLE public.schools_users OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    school_id uuid NOT NULL,
    login text NOT NULL,
    password text NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_salts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users_salts (
    user_id uuid NOT NULL,
    salt text DEFAULT public.gen_salt('bf'::text) NOT NULL
);


ALTER TABLE public.users_salts OWNER TO postgres;

--
-- Data for Name: schools; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools (id, title, region, city, area, email, members) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	МБОУ "Гимназия №125"	116	Казань	Советский район	test@gmail.com	{"6657cbe7-0d5c-4592-8cc7-997e26bb143b": {"roles": ["admin", "teacher", "dev"], "classes": []}, "96ff9707-cdee-46e9-a0d3-e30e772cf416": {"roles": [], "classes": []}, "a58e750a-63ca-47f5-837e-502c8d6c227c": {"roles": [], "classes": []}, "bd10f251-db64-4092-b0b1-2f2fbfc5f768": {"roles": ["dev", "teacher"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd"]}, "c419f7f6-ac38-432a-a4b0-54a315f835b2": {"roles": ["admin", "teacher", "dev"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd", "e7a2c4e3-525c-4433-b5d7-9e085d43d661"]}}
00000000-0000-0000-0000-000000000000	nil	nil	nil	nil	nil	{"82b4b650-1f1d-4868-be93-0bc98b1c5190": {"roles": [], "classes": []}, "934ced4e-ee81-4b21-96c7-fd6a67aaf19f": {"roles": ["teacher"], "classes": ["e3ec4a16-365a-4b6d-ac3f-79182df83701"]}, "ac7d9df6-9141-461b-bd12-f59370fb9826": {"roles": ["tester", "teacher", "admin"], "classes": []}, "c7bf75c9-2426-42e0-9cc0-47b8eb1d34d5": {"roles": ["apitest1", "teacher"], "classes": ["e3ec4a16-365a-4b6d-ac3f-79182df83701"]}, "ff856428-37b2-4c21-a1d7-ed647b514e27": {"roles": [], "classes": []}}
\.


--
-- Data for Name: schools_change_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_change_logs (id, school_id, user_id, category, operation, changed_property, object_id, changed_at, row_data) FROM stdin;
96	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	fd3d4a52-f734-40f4-80ae-b430391e15a1	2025-03-17 18:05:17.721983	{"new": {"name": "fdsaf"}, "old": {"name": "adsf"}}
156	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	059db160-8da8-42c6-b547-d6c852d81a32	2025-03-18 00:21:14.29734	{"name": "test", "owners": [{"id": "de41a530-0298-4f87-96aa-01e6ca805e4a", "name": "fasd"}], "students": [], "fstudents": []}
157	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	462c1817-78d6-4514-ab6e-42c72a8ebc02	2025-03-18 00:21:16.911067	{"name": "test", "owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}], "students": [], "fstudents": []}
118	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:31:39.13132	{"new": {"name": "ChangeNameDummy2"}, "old": {"name": "ChangeNameDummy2"}}
158	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	0f80d9d7-4ced-4792-b01a-69ceb1a85347	2025-03-18 00:21:19.846904	{"name": "testest", "owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}], "students": [], "fstudents": []}
161	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 12:57:30.660737	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
162	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 12:58:39.305883	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
163	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 12:59:27.884554	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
164	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 12:59:35.729513	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
165	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:01:29.148795	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
166	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:01:39.554507	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
167	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:02:12.336865	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
168	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:03:15.841936	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
169	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:03:27.644314	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
170	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:03:43.064823	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
171	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:04:00.762305	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
172	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:04:29.164146	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
173	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:04:50.535628	{"date": "2025-03-17", "absent": {"ORVI": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна"], "respectful": ["Андреев Георгий Дмитриевич"], "not_respectful": []}}
174	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:05:28.705575	{"date": "2025-03-17", "absent": {"ORVI": [], "respectful": [], "not_respectful": []}}
175	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:05:44.289264	{"date": "2025-03-17", "absent": {"ORVI": ["Иванов Иван Иванович"], "respectful": ["Кожевникова Алина Ивановна"], "not_respectful": []}}
176	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:07:02.828065	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
177	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:08:23.190148	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
178	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:08:47.791944	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
179	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:10:22.965279	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
180	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:10:31.579804	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна"], "respectful": [], "not_respectful": []}}
181	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:10:45.330691	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}}
97	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	fd3d4a52-f734-40f4-80ae-b430391e15a1	2025-03-17 18:11:32.070689	{"new": {"students": ["adsf", "asdf", "fdf"], "fstudents": ["asdf"]}, "old": {"students": [], "fstudents": []}}
159	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 00:29:00.748686	{"date": "2025-03-17", "absent": {"ORVI": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна"], "respectful": ["Андреев Георгий Дмитриевич"], "not_respectful": []}}
182	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:12:06.804564	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}}
183	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	create	\N	\N	2025-03-18 13:12:54.782854	{"name": "asdf", "owner": {"id": null, "name": null}}
184	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	create	\N	\N	2025-03-18 13:13:08.983433	{"name": "testetsetsetes", "owner": {"id": null, "name": null}}
185	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:13:15.530448	{"new": {"students": ["sadf"], "fstudents": []}, "old": {"students": [], "fstudents": []}}
186	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:13:38.025675	{"new": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}, "old": {"students": ["sadf"], "fstudents": []}}
187	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:14:19.249072	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}}
188	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 13:14:20.874329	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}}
189	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:14:44.230019	{"new": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}, "old": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}}
190	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:14:45.28326	{"new": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}, "old": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}}
191	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:14:49.976973	{"new": {"students": ["sadf"], "fstudents": []}, "old": {"students": ["sadf", "asdf"], "fstudents": ["sadf"]}}
192	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:16:27.104804	{"new": {"name": "RENAMED"}, "old": {"name": "asdf"}}
193	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:18:31.794047	{"new": {"name": "RENAMEDRENAMED2"}, "old": {"name": "RENAMED"}}
194	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:18:36.807622	{"new": {"name": "RENAMEDRENAMED2"}, "old": {"name": "RENAMEDRENAMED2"}}
195	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:18:40.407924	{"new": {"name": "RENAMEDRENAMED"}, "old": {"name": "RENAMEDRENAMED2"}}
196	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	name	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:20:04.441076	{"new": {"name": "RENAME"}, "old": {"name": "RENAMEDRENAMED"}}
197	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:20:28.084597	{"new": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}, "old": {"students": [], "fstudents": []}}
198	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:20:35.656924	{"new": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}, "old": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}}
199	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:20:36.563724	{"new": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}, "old": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}}
160	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 00:39:22.699328	{"date": "2025-03-18", "absent": {"ORVI": ["Иванов Иван Иванович", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич"], "respectful": ["Кожевникова Алина Ивановна"], "not_respectful": []}}
200	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:21:03.861101	{"new": {"students": ["fadsf", "fda", "asdf"], "fstudents": ["fadsf"]}, "old": {"students": ["fadsf", "fda"], "fstudents": ["fadsf"]}}
201	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:21:12.026849	{"new": {"students": ["fadsf", "fda", "fdasf", "asdf"], "fstudents": ["fadsf"]}, "old": {"students": ["fadsf", "fda", "asdf"], "fstudents": ["fadsf"]}}
133	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:50:29.61772	{"new": {"name": "ChangeNameDummy2"}, "old": {"name": "ChangeNameDummy2"}}
202	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	students	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:21:17.873533	{"new": {"students": ["fadsf", "fda", "fdasf", "asdf"], "fstudents": ["fadsf", "fda", "fdasf"]}, "old": {"students": ["fadsf", "fda", "fdasf", "asdf"], "fstudents": ["fadsf"]}}
203	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	owners	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:21:34.223096	{"new": {"owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}, {"id": "de41a530-0298-4f87-96aa-01e6ca805e4a", "name": "fasd"}]}, "old": {"owners": []}}
204	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	owners	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	2025-03-18 13:21:36.208414	{"new": {"owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}]}, "old": {"owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}, {"id": "de41a530-0298-4f87-96aa-01e6ca805e4a", "name": "fasd"}]}}
206	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	create	\N	\N	2025-03-18 13:22:05.130918	{"name": "afdasdf", "login": "56c5217ae98b6ce3a1929e90d9620722f39e78fb3641a55c45928b71b0e36aa8", "roles": ["teacher", "admin"], "classes": [{"id": "14eb9197-8e87-4529-89a7-53cc38000616", "name": "adf"}], "password": "2413fb3709b05939f04cf2e92f7d0897fc2596f9ad0b8a9ea855c7bfebaae892"}
207	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	create	\N	\N	2025-03-18 13:23:47.339494	{"name": "fasdf", "login": "2413fb3709b05939f04cf2e92f7d0897fc2596f9ad0b8a9ea855c7bfebaae892", "roles": ["teacher", "admin"], "classes": [{"id": "9abff5ff-20f4-4bf9-bf18-8c1d4910d073", "name": "RENAME"}], "password": "d68eae7ede9d4d4eec5e3fc0d8393e65b4fa63e649a4377118321a4fb93fd432"}
208	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	2d670e81-1c69-4cbf-a463-79ec48340ae3	2025-03-18 13:24:05.087428	{"new": {"name": "gfsa"}, "old": {"name": "fasdf"}}
209	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	2d670e81-1c69-4cbf-a463-79ec48340ae3	2025-03-18 13:25:16.213137	{"new": {"name": "fda"}, "old": {"name": "gfsa"}}
136	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:51:38.668401	{"new": {"name": "ChangeNameDummy2"}, "old": {"name": "ChangeNameDummy2"}}
211	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	2d670e81-1c69-4cbf-a463-79ec48340ae3	2025-03-18 13:28:51.782121	{"new": {"classes": [{"id": "38ed868c-f944-46ac-974b-62b519fb47bf", "name": "testetsetsetes"}]}, "old": {"classes": []}}
212	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	2d670e81-1c69-4cbf-a463-79ec48340ae3	2025-03-18 13:28:55.48612	{"new": {"classes": [{"id": "38ed868c-f944-46ac-974b-62b519fb47bf", "name": "testetsetsetes"}]}, "old": {"classes": [{"id": "38ed868c-f944-46ac-974b-62b519fb47bf", "name": "testetsetsetes"}]}}
138	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:53:49.648006	{"new": {"classes": [{"id": "ab981c19-92e9-4a4c-b4df-0a14c489cced", "name": "ЕСТЬВладелец"}, {"id": "7f98040d-7619-4a92-b3be-9e21b81cfc04", "name": "asdf"}]}, "old": {"classes": [{"id": "ab981c19-92e9-4a4c-b4df-0a14c489cced", "name": "ЕСТЬВладелец"}, {"id": "7f98040d-7619-4a92-b3be-9e21b81cfc04", "name": "asdf"}]}}
139	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:53:49.648006	{"new": {"name": "ChangeNameDummy2"}, "old": {"name": "ChangeNameDummy2"}}
214	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	delete	\N	78addb0a-9f07-4576-b0df-e51648bc3401	2025-03-18 13:29:06.824572	{"name": "fasdf", "roles": ["teacher", "admin"], "classes": []}
215	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	delete	\N	2d670e81-1c69-4cbf-a463-79ec48340ae3	2025-03-18 13:29:11.012283	{"name": "fda", "roles": ["teacher", "admin"], "classes": []}
216	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	password	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-18 13:29:21.754109	\N
101	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	owners	fd3d4a52-f734-40f4-80ae-b430391e15a1	2025-03-17 18:40:03.182076	{"new": {"owners": []}, "old": {"owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}]}}
140	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	roles	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:54:32.823972	{"new": {"roles": ["teacher", "admin"]}, "old": {"roles": ["teacher", "admin"]}}
141	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:54:32.823972	{"new": {"classes": [{"id": "ab981c19-92e9-4a4c-b4df-0a14c489cced", "name": "ЕСТЬВладелец"}, {"id": "7f98040d-7619-4a92-b3be-9e21b81cfc04", "name": "asdf"}]}, "old": {"classes": [{"id": "ab981c19-92e9-4a4c-b4df-0a14c489cced", "name": "ЕСТЬВладелец"}, {"id": "7f98040d-7619-4a92-b3be-9e21b81cfc04", "name": "asdf"}]}}
83	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	213501c8-76b8-4713-8e41-453f9bc35af9	2025-03-17 17:05:17.380091	{"name": "classWithoutOwner", "owners": [], "students": [], "fstudents": []}
84	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	e159bdb6-3b76-45d3-a90f-e49b36df704d	2025-03-17 17:05:19.646195	{"name": "classWithOwner", "owners": [], "students": [], "fstudents": []}
85	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	b577f972-5152-485e-b1b5-3f6ee14bf1d4	2025-03-17 17:05:22.526577	{"name": "rwar", "owners": [], "students": [], "fstudents": []}
142	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	d64f9b23-4a8a-4c95-aafa-b99558a8578b	2025-03-17 20:54:32.823972	{"new": {"name": "ChangeNameDummy2"}, "old": {"name": "ChangeNameDummy2"}}
86	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	48d873b4-f7a7-4e29-a75b-129e8657d4f3	2025-03-17 17:06:32.386658	{"name": "123", "owners": [], "students": [], "fstudents": []}
221	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-18 13:37:29.638146	{"new": {"classes": []}, "old": {"classes": []}}
222	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	delete	\N	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-18 13:41:58.347741	{"name": "fasd", "roles": ["teacher"], "classes": []}
223	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	14eb9197-8e87-4529-89a7-53cc38000616	2025-03-18 13:49:05.536217	{"name": "adf", "owners": [{"id": "614b5107-b43d-483b-98cf-3b30c8c7e35b", "name": "afdasdf"}], "students": [], "fstudents": []}
224	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	54bca87b-06f1-4636-9d0b-5c1e23fbe96a	2025-03-18 13:49:12.67385	{"name": "asdf", "owners": [], "students": [], "fstudents": []}
225	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	1aea266a-704c-449b-b9a8-04983af9eb2d	2025-03-18 13:49:15.463236	{"name": "124", "owners": [], "students": [], "fstudents": []}
226	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	7f98040d-7619-4a92-b3be-9e21b81cfc04	2025-03-18 13:49:18.436975	{"name": "asdf", "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "ChangeNameDummy2"}], "students": [], "fstudents": []}
227	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	delete	\N	38ed868c-f944-46ac-974b-62b519fb47bf	2025-03-18 13:49:35.198466	{"name": "testetsetsetes", "owners": [], "students": ["sadf"], "fstudents": []}
145	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	invites	create	\N	\N	2025-03-17 21:31:00.713381	{"name": "asdfe", "roles": ["teacher", "admin"], "classes": ["14eb9197-8e87-4529-89a7-53cc38000616", "54bca87b-06f1-4636-9d0b-5c1e23fbe96a"]}
146	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	invites	delete	\N	\N	2025-03-17 21:31:03.910171	{"invite": {"id": "317160", "body": {"name": "asdfe", "roles": ["teacher", "admin"], "classes": [{"id": "14eb9197-8e87-4529-89a7-53cc38000616", "name": "adf"}, {"id": "54bca87b-06f1-4636-9d0b-5c1e23fbe96a", "name": "asdf"}]}}}
147	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	769583fe-a2cc-485c-99b8-eb2b3b9495a9	2025-03-17 22:41:03.56117	{"new": {"name": "321"}, "old": {"name": "124"}}
148	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	769583fe-a2cc-485c-99b8-eb2b3b9495a9	2025-03-17 22:41:31.881782	{"new": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}, {"id": "14eb9197-8e87-4529-89a7-53cc38000616", "name": "adf"}]}, "old": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}]}}
149	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	769583fe-a2cc-485c-99b8-eb2b3b9495a9	2025-03-17 22:42:14.561584	{"new": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}]}, "old": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}, {"id": "14eb9197-8e87-4529-89a7-53cc38000616", "name": "adf"}]}}
150	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	769583fe-a2cc-485c-99b8-eb2b3b9495a9	2025-03-17 22:42:53.859939	{"new": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}]}, "old": {"classes": [{"id": "8f9598e5-e230-4576-8971-9abba430aeda", "name": "НЕТВладелец"}]}}
151	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	roles	769583fe-a2cc-485c-99b8-eb2b3b9495a9	2025-03-17 22:43:04.662852	{"new": {"roles": ["teacher"]}, "old": {"roles": ["teacher", "admin"]}}
152	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	classes	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-17 23:41:12.038531	{"new": {"classes": [{"id": "059db160-8da8-42c6-b547-d6c852d81a32", "name": "test"}]}, "old": {"classes": [{"id": "059db160-8da8-42c6-b547-d6c852d81a32", "name": "test"}, {"id": "1aea266a-704c-449b-b9a8-04983af9eb2d", "name": "124"}]}}
153	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	name	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-17 23:41:17.239752	{"new": {"name": "fasd"}, "old": {"name": "asdf"}}
154	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	users	edit	roles	de41a530-0298-4f87-96aa-01e6ca805e4a	2025-03-17 23:41:20.151158	{"new": {"roles": ["teacher"]}, "old": {"roles": ["teacher", "admin"]}}
155	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-18 00:00:02.925519	{"date": "2025-03-18", "absent": {"ORVI": [], "respectful": [], "not_respectful": []}}
107	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	owners	fd3d4a52-f734-40f4-80ae-b430391e15a1	2025-03-17 19:15:14.385058	{"new": {"owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}]}, "old": {"owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}]}}
108	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	edit	owners	fd3d4a52-f734-40f4-80ae-b430391e15a1	2025-03-17 19:15:40.318678	{"new": {"owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}, {"id": "03bd1f7f-e140-4909-91b5-c9bf27eba530", "name": "Демо Пользователь"}]}, "old": {"owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}]}}
94	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	classes	create	\N	\N	2025-03-17 17:27:21.946055	{"name": "asdf", "owner": {"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}}
95	00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	data	edit	absent	19baa673-b8bd-4af1-af51-20c618007060	2025-03-17 17:36:41.758688	{"date": "2025-03-17", "absent": {"ORVI": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна"], "respectful": ["Андреев Георгий Дмитриевич"], "not_respectful": ["Голубева Валерия Романовна"]}}
\.


--
-- Data for Name: schools_classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_classes (school_id, class_id, class_body) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	39f58698-a861-477a-b06d-56c31aa69624	{"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["Иванов Иван Иваныч", "Филипп Киркоров Великий ", "Помещик Добрый", "Герой народа", "Александр Македонский", "Виктор Сочный"], "fstudents": []}
00000000-0000-0000-0000-000000000000	fd3d4a52-f734-40f4-80ae-b430391e15a1	{"name": "fdsaf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["adsf", "asdf", "fdf"], "fstudents": ["asdf"]}
00000000-0000-0000-0000-000000000000	19baa673-b8bd-4af1-af51-20c618007060	{"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Львова Анастасия Фёдоровна"]}
00000000-0000-0000-0000-000000000000	9abff5ff-20f4-4bf9-bf18-8c1d4910d073	{"name": "RENAME", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["fadsf", "fda", "fdasf", "asdf"], "fstudents": ["fadsf", "fda", "fdasf"]}
00000000-0000-0000-0000-000000000000	8f9598e5-e230-4576-8971-9abba430aeda	{"name": "НЕТВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	ab981c19-92e9-4a4c-b4df-0a14c489cced	{"name": "ЕСТЬВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	b17f87f0-7242-4dae-8415-78976fb2eab1	{"name": "уые", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
\.


--
-- Data for Name: schools_classes_ownership; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_classes_ownership (school_id, user_id, class_id) FROM stdin;
00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	19baa673-b8bd-4af1-af51-20c618007060
64e40f2f-2bba-484f-bf95-00ae047ca171	96ff9707-cdee-46e9-a0d3-e30e772cf416	39f58698-a861-477a-b06d-56c31aa69624
00000000-0000-0000-0000-000000000000	d64f9b23-4a8a-4c95-aafa-b99558a8578b	ab981c19-92e9-4a4c-b4df-0a14c489cced
00000000-0000-0000-0000-000000000000	03bd1f7f-e140-4909-91b5-c9bf27eba530	b17f87f0-7242-4dae-8415-78976fb2eab1
00000000-0000-0000-0000-000000000000	03bd1f7f-e140-4909-91b5-c9bf27eba530	fd3d4a52-f734-40f4-80ae-b430391e15a1
00000000-0000-0000-0000-000000000000	769583fe-a2cc-485c-99b8-eb2b3b9495a9	8f9598e5-e230-4576-8971-9abba430aeda
\.


--
-- Data for Name: schools_data; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_data (school_id, date, data) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-06-22	{}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-06-29	{"1_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-06-28	{"1_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-01	{"1_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Б": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_В": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Г": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Д": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "2_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "3_Е": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-11	{"1_А": {"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}, "1_Б": {"amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "absent_amount": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_students": [], "list_fstudents": []}, "1_В": {"amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "absent_amount": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_students": [], "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-12	{"2423b285-eb67-4887-bb60-c081ff3170ac": {"name": "1_В", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "absent_amount": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_students": [], "list_fstudents": []}, "91cb7c53-8ea7-4fa3-a4bd-eee234aac918": {"name": "1_Б", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "absent_amount": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_students": [], "list_fstudents": []}, "96a99d12-9519-4963-a84e-fdc05bfc368d": {"name": "1_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "absent_amount": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_students": [], "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-16	{"2423b285-eb67-4887-bb60-c081ff3170ac": {"name": "1_В", "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 1, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "91cb7c53-8ea7-4fa3-a4bd-eee234aac918": {"name": "1_Б", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "96a99d12-9519-4963-a84e-fdc05bfc368d": {"name": "1_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-20	{"2423b285-eb67-4887-bb60-c081ff3170ac": {"name": "1_В", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "91cb7c53-8ea7-4fa3-a4bd-eee234aac918": {"name": "1_Б", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "96a99d12-9519-4963-a84e-fdc05bfc368d": {"name": "1_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-21	{"2423b285-eb67-4887-bb60-c081ff3170ac": {"name": "1_В", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "91cb7c53-8ea7-4fa3-a4bd-eee234aac918": {"name": "1_Б", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "96a99d12-9519-4963-a84e-fdc05bfc368d": {"name": "1_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-07-25	{"2423b285-eb67-4887-bb60-c081ff3170ac": {"name": "1_В", "owner": {"id": "c419f7f6-ac38-432a-a4b0-54a315f835b2", "name": "Alexandr"}, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "64e1779b-8f5a-4bd0-a6a9-acf58563aa0e": {"name": "10_А", "owner": {"id": null, "name": null}, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "91cb7c53-8ea7-4fa3-a4bd-eee234aac918": {"name": "1_Б", "owner": {"id": "c419f7f6-ac38-432a-a4b0-54a315f835b2", "name": "Alexandr"}, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "96a99d12-9519-4963-a84e-fdc05bfc368d": {"name": "1_А", "owner": {"id": "c419f7f6-ac38-432a-a4b0-54a315f835b2", "name": "Alexandr"}, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-07-28	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Tempoev", "Kakov"], "fstudents": ["Ivanov"], "respectful": ["Tempoev1"], "not_respectful": ["Kakov"]}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 1}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-07-27	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-07-30	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Tempoev", "Kakov"], "fstudents": ["Ivanov"], "respectful": ["Tempoev"], "not_respectful": ["Kakov"]}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 1}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-08-07	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Tempoev", "Kakov"], "fstudents": ["Ivanov"], "respectful": ["Tempoev"], "not_respectful": ["Kakov"]}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 1}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-08-10	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-09-01	{"08514837-d0ab-406e-8583-2c950e120287": {"name": "098", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "c5cb143c-b3de-4d00-ae61-25ef75b082c6": {"name": "etstsetsetsetest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": ["Efimov"], "list_fstudents": [], "isClassDataFilled": false}, "d910deba-6d6c-4b77-a97b-44bbb1ea634a": {"name": "testClass#3", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 4, "owners": [{"id": "82ef00ca-96bc-48b2-8eac-d0768a4ece81", "name": "Юлия Александровна"}, {"id": "934ced4e-ee81-4b21-96c7-fd6a67aaf19f", "name": "api-test"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e12f4928-aa63-41e1-8bd8-d508ccf0e6e0": {"name": "naturalClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 25, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Egorov"], "list_fstudents": ["Egorov"], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5", "Efimov", "1", "2", "3", "4", "5", "6", "7", "8", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "list_fstudents": ["Ivanov5", "Ivanov4", "Ivanov3", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-25	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["124"], "global": ["124", "431"], "fstudents": [], "respectful": [], "not_respectful": ["431"]}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "3fb6418a-50d5-4e0d-8c6d-b65aae5a2417": {"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "62e4c1af-29b7-4d6d-861e-2b18b6e2d8c6": {"name": "4А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "68a35172-ad26-4a93-ab66-49d647c67ef7": {"name": "10Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": ["321", "123"], "global": ["321", "123", "512"], "fstudents": [], "respectful": ["512"], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": true}, "c02c7d4b-f98e-498c-80e2-9e120387ac16": {"name": "4Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": ["stud2", "stud32"], "global": ["stud2", "stud32"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-14	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-09-19	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "123", "absent": {"ORVI": ["Tester2"], "global": ["Tester2"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-16	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "c7bf75c9-2426-42e0-9cc0-47b8eb1d34d5", "name": "api-test"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-08-19	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2025-02-01	{"39f58698-a861-477a-b06d-56c31aa69624": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "96ff9707-cdee-46e9-a0d3-e30e772cf416", "name": "Юлия Александровна"}], "students": ["Иванов Иван Иваныч", "Филипп Киркоров Великий ", "Помещик Добрый", "Герой народа", "Александр Македонский", "Виктор Сочный"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-08-23	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": [], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-24	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "amount": 0, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "list_fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-26	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "amount": 0, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "list_fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-27	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "amount": 0, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "list_fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-28	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": ["Ivanov0"], "global": ["Ivanov0", "Ivanov5"], "fstudents": [], "respectful": [], "not_respectful": ["Ivanov5"]}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": true}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "934ced4e-ee81-4b21-96c7-fd6a67aaf19f", "name": "api-test"}, {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov4"], "global": ["Ivanov4", "Ivanov0", "Ivanov2", "Ivanov1"], "fstudents": [], "respectful": ["Ivanov0", "Ivanov1"], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "list_fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-21	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["3124"], "global": ["124", "3124"], "fstudents": [], "respectful": ["124"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": ["ыегв1"], "global": ["ыегв1"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-20	{"09afbab9-46a5-4a17-b80e-997fb93d7c30": {"name": "3_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "1e43b107-20d9-4056-a921-ea4f7124aa5e": {"name": "2_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["3124", "431"], "global": ["124", "431", "3124"], "fstudents": [], "respectful": ["124"], "not_respectful": []}, "owners": [], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "4dbd7726-da96-4d05-9dbb-25f4e57c4063": {"name": "7_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "123", "absent": {"ORVI": ["Tester"], "global": ["Tester"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "7f309bfe-bb9f-4338-b370-1cb27824ae15": {"name": "12_А", "absent": {"ORVI": ["123", "321", "4123"], "global": ["321", "4123", "123"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "4123"], "fstudents": ["4123"], "isClassDataFilled": true}, "a57ec99f-71c6-480d-8d91-525d43af4ea3": {"name": "10_А", "absent": {"ORVI": [], "global": ["4124"], "fstudents": [], "respectful": [], "not_respectful": ["4124"]}, "owners": [], "students": ["4124", "12412", "531"], "fstudents": [], "isClassDataFilled": true}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": false}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": false}, "e06fb84a-4e40-40e9-92ff-9d7ff2f67998": {"name": "9_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": [], "global": ["stud32"], "fstudents": [], "respectful": ["stud32"], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": true}, "e2f7158a-27b5-41e9-812e-2b25d3ed50ab": {"name": "6_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "f1d9a36a-f4bd-4330-a9b7-3c5c3ac1df99": {"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-02	{"08514837-d0ab-406e-8583-2c950e120287": {"name": "098", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "c5cb143c-b3de-4d00-ae61-25ef75b082c6": {"name": "etstsetsetsetest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": ["Efimov"], "list_fstudents": [], "isClassDataFilled": false}, "d1c414b0-57bb-4c24-abfb-f61c14412b0b": {"name": "123", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 123, "owners": [], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "d910deba-6d6c-4b77-a97b-44bbb1ea634a": {"name": "testClass#3", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 4, "owners": [{"id": "82ef00ca-96bc-48b2-8eac-d0768a4ece81", "name": "Юлия Александровна"}, {"id": "934ced4e-ee81-4b21-96c7-fd6a67aaf19f", "name": "api-test"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e12f4928-aa63-41e1-8bd8-d508ccf0e6e0": {"name": "naturalClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 25, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Egorov"], "list_fstudents": ["Egorov"], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov0", "Ivanov3"], "global": ["Ivanov0", "Ivanov1", "Ivanov3"], "fstudents": [], "respectful": ["Ivanov1"], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5", "Efimov", "1", "2", "3", "4", "5", "6", "7", "8", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "list_fstudents": ["Ivanov5", "Ivanov4", "Ivanov3", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-30	{"43746cdc-5be1-4b66-96fe-e5b630d4a865": {"name": "testClass#1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": ["123", "321"], "list_fstudents": ["123"], "isClassDataFilled": false}, "6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "8f0f242c-c29a-4c68-9e2e-c6b6b1875ed8": {"name": "123", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 123, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "d4c94a63-f124-4c76-8382-fcff2c1a06cc": {"name": "testClass#2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 10, "owners": [{"id": "00000000-0000-0000-0000-000000000000", "name": "nil"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "934ced4e-ee81-4b21-96c7-fd6a67aaf19f", "name": "api-test"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "eab74de0-001e-4e1e-93e0-c9ee922991b7": {"name": "finalTest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 100, "owners": [], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": ["Ivanov0"], "global": ["Ivanov0", "Ivanov2", "Ivanov1"], "fstudents": [], "respectful": ["Ivanov1"], "not_respectful": ["Ivanov2"]}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5", "Efimov"], "list_fstudents": ["Ivanov5", "Ivanov4", "Ivanov3"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-09	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "10_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-07	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "10_А", "absent": {"ORVI": ["Tester2"], "global": ["Tester2"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-06	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "10_А", "absent": {"ORVI": ["Tester"], "global": ["Tester2", "Tester"], "fstudents": [], "respectful": [], "not_respectful": ["Tester2"]}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": [], "fstudents": [], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": ["123"], "global": ["123"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-10	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "10_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": false}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-11	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "10_А", "absent": {"ORVI": ["Tester", "Tester2"], "global": ["Tester2", "Tester"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-14	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "123", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": false}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": ["123"], "fstudents": [], "respectful": [], "not_respectful": ["123"]}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-26	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": false}, "3fb6418a-50d5-4e0d-8c6d-b65aae5a2417": {"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "62e4c1af-29b7-4d6d-861e-2b18b6e2d8c6": {"name": "4А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "68a35172-ad26-4a93-ab66-49d647c67ef7": {"name": "10Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": false}, "c02c7d4b-f98e-498c-80e2-9e120387ac16": {"name": "4Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-09-22	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": [], "global": ["124"], "fstudents": [], "respectful": ["124"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": ["ыегв1"], "global": ["ыегв1"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-10-13	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Красавица :heart"], "global": ["Красавица :heart"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Красавица :heart"], "fstudents": ["Красавица :heart"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-10-19	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Красавица :heart"], "fstudents": ["Красавица :heart"], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-10-04	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["3124", "124"], "global": ["124", "431", "3124"], "fstudents": [], "respectful": ["431"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "3fb6418a-50d5-4e0d-8c6d-b65aae5a2417": {"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "62e4c1af-29b7-4d6d-861e-2b18b6e2d8c6": {"name": "4А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "68a35172-ad26-4a93-ab66-49d647c67ef7": {"name": "10Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": false}, "c02c7d4b-f98e-498c-80e2-9e120387ac16": {"name": "4Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": false}}
64e40f2f-2bba-484f-bf95-00ae047ca171	2024-11-05	{"39f58698-a861-477a-b06d-56c31aa69624": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "96ff9707-cdee-46e9-a0d3-e30e772cf416", "name": "Юлия Александровна"}], "students": ["Иванов Иван Иваныч", "Филипп Киркоров Великий ", "Помещик Добрый", "Герой народа", "Александр Македонский", "Виктор Сочный"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-10-20	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["123", "0000"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-10-23	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["1111", "втвтч"], "global": ["втвтч", "1111"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["0000", "123", "312312", "123", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["0000"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-11-14	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович", "3124"], "global": ["4214", "туцть", "Иванов Иван Иванович", "3124"], "fstudents": ["туцть", "Иванов Иван Иванович"], "respectful": ["4214"], "not_respectful": ["туцть"]}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-11-11	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": ["Иванов Иван Иванович"], "fstudents": ["Иванов Иван Иванович"], "respectful": ["Иванов Иван Иванович"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-11-15	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович"], "global": ["Иванов Иван Иванович"], "fstudents": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-12-30	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": false}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-01-12	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович"], "global": ["Иванов Иван Иванович", "3124"], "fstudents": ["Иванов Иван Иванович"], "respectful": ["3124"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": ["123"], "global": ["123"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": true}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": ["123"], "fstudents": [], "respectful": ["123"], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2025-01-29	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Львова Анастасия Фёдоровна"], "isClassDataFilled": false}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-02-01	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Львова Анастасия Фёдоровна"], "isClassDataFilled": false}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-02-02	{"01561438-dad6-4f53-8f05-62ef3bbde332": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "0ac6cefb-0e6a-4b8c-a4f1-7f050242dc5f": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "0af96c0c-00ab-4f11-a6ce-d19c0cf65fad": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "0c4da9bf-6162-44aa-a8d3-2812cc853169": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "0cf4067b-4a05-43a4-a36e-736c75d9050f": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "119fee2b-fcfa-4059-8d9b-468facc4a04b": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "12735369-63d3-44be-b357-4ffceb5cf2ae": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Львова Анастасия Фёдоровна"], "global": ["Львова Анастасия Фёдоровна", "Кожевникова Алина Ивановна", "Иванов Иван Иванович"], "fstudents": ["Львова Анастасия Фёдоровна", "Иванов Иван Иванович"], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Львова Анастасия Фёдоровна"], "isClassDataFilled": true}, "1b46a2aa-f7ac-48d8-bf0a-b247e8e2f1fd": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "1f5341c8-93d8-445c-b4a0-53266cfa10af": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "2f8b6216-c022-4d99-870a-ed3a90f53194": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "35eaf16a-6ce7-44cd-995b-983ac01f722f": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "38ede673-28d8-4044-ab97-7cf341c3d394": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "3c790a72-172d-4929-a0dd-b9a02a97a949": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "3eb160b8-900b-4ac0-a8cf-e7e3fa25cb87": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "40fdbbb7-938f-41a3-8c0e-b3d930a290d2": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "43a0b296-77ba-4fe3-b1cc-12b33c01c88a": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "45fe5932-6269-449b-8f98-3deb72bed497": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "48800cac-8800-43fc-9751-aad33e1b1488": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "48d873b4-f7a7-4e29-a75b-129e8657d4f3": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}, "4cd6cb5c-cad7-4044-85d0-8453b16ec187": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4ec60ce5-b34b-4b6c-80c8-601cf4b0349f": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "52264204-6036-487f-a7f6-1111326daf1b": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "53b6f41b-b5b7-4430-af08-9dfe7f95dbb2": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "58af2ac1-ab4a-4202-8ddd-791037b27d16": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "5af02cb4-7e74-47ff-99f3-d9bd08ae47b7": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "5ecda3c3-a989-4f3a-899c-0fb03045acfb": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "627f38f7-447c-4c34-accb-bdb0af0eb0d8": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "693a57bb-ef27-40cb-bf32-496e237c6ff6": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "6a9a4028-1426-4d41-8c05-823411156833": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "6cbfb92e-1e70-4429-ade7-11baea875d5c": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "7bac4ccf-c215-44d6-9ef3-d6fa6dd67e1f": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "8120415a-c910-4ea1-9d49-aca202f5a35b": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "92d9a037-54fe-4c11-9a71-a663b8d04d5e": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "aa3fc913-0929-4cd1-824e-f614c8fe6789": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "ad152261-6ea6-4915-9ef0-f3444a707cb6": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "aec5ba79-775f-4d7a-bc17-a18593369352": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "afd0d02b-4e19-4042-9daf-eaed6da7809c": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b445834e-834b-44ad-a01b-e2ec5ec29872": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b8b5880e-6c0d-406a-8b3d-085d7b637061": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "be248dc1-a55f-46cb-92fb-2d4770f7c08e": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "c47a2eeb-b82e-4143-9190-d32eaf1de89e": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "c862a532-9dda-4501-b09d-321d6ced4b9a": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "cd48303a-d5e5-4cd8-8c00-392583a89c48": {"name": "testclass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "ce50ae8a-a18d-4f93-b7e0-dae22b18da79": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "d3f01f0d-025f-4e5e-8045-8f42557d5e78": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "d6d8ad88-b74d-4de5-81c7-6ec558307f2c": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "d7c6ce11-5d08-4b54-8d67-28e9fd414c86": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e31d2f43-1f69-408e-8a93-7abc9005f812": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e71a4fe9-d84a-4fe7-8529-4a88e21cd590": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e8ba4232-bcd9-4832-9601-a30f04d4a2cb": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "eb977bf6-d688-4fb5-80ce-170770660e2b": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "ee522c77-1ca4-4451-a186-593e38cc5cfb": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "f0f82f2b-a225-402e-a021-1a81397eea6a": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "f4332b36-b342-4714-b12a-dc8e8610d581": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "f887079c-dab8-4b0f-93ac-b81ef3df914e": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "ff12fedc-ba50-45a6-875b-d2ef018b7441": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "fffe4fe7-a78f-42c6-b004-0b1feb56d2b1": {"name": "testClassTemp", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-11-12	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["3124", "Иванов Иван Иванович"], "global": ["туцть", "Иванов Иван Иванович", "3124"], "fstudents": ["туцть", "Иванов Иван Иванович"], "respectful": ["туцть"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-01-17	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович"], "global": ["Иванов Иван Иванович", "3124"], "fstudents": ["Иванов Иван Иванович"], "respectful": ["3124"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "52c68b48-d797-4ef5-8c59-8a3dad26a54f", "name": "123321"}, {"id": "1550ec92-41fe-45da-a694-124b658dabe3", "name": "simpleuser"}], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-11-18	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": false}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-11-23	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович", "3124", "4214"], "global": ["4214", "Иванов Иван Иванович", "3124"], "fstudents": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "455406f7-3c06-4b83-99b7-fe22f4474ff8": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-11-24	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович", "3124"], "global": ["4214", "Иванов Иван Иванович", "3124"], "fstudents": ["Иванов Иван Иванович"], "respectful": ["4214"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "455406f7-3c06-4b83-99b7-fe22f4474ff8": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": ["123", "234"], "global": ["123", "234"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-11-28	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "вьыты", "втвтч"], "global": ["влвл", "1251612", "4214", "вьыты", "5121621", "втвтч", "дмвжжы", "туцть", "Иванов Иван Иванович", "3124"], "fstudents": ["туцть", "Иванов Иван Иванович"], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "455406f7-3c06-4b83-99b7-fe22f4474ff8": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2024-12-29	{"19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Иванов Иван Иванович", "3124", "4214", "5121621", "1251612", "влвл", "туцть", "дмвжжы", "ьввьв", "вьыты", "чьяьч", "втвтч", "ьввьвь"], "fstudents": ["Иванов Иван Иванович", "туцть"], "isClassDataFilled": true}, "21f50302-c5a3-49c6-8777-77a59dc1303a": {"name": "forbiddenClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "70ad236e-9894-489a-93e7-f64fcb8cb60d", "name": "testerBugUser"}], "students": ["123", "321"], "fstudents": [], "isClassDataFilled": false}, "455406f7-3c06-4b83-99b7-fe22f4474ff8": {"name": "1А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4c0fd90f-c95f-4771-a779-7e943365c744": {"name": "testClassIfNo5Class", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123", "234", "345"], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-03-17	{"059db160-8da8-42c6-b547-d6c852d81a32": {"name": "test", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "0f80d9d7-4ced-4792-b01a-69ceb1a85347": {"name": "testest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "14eb9197-8e87-4529-89a7-53cc38000616": {"name": "adf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович"], "global": ["Кожевникова Алина Ивановна", "Иванов Иван Иванович"], "fstudents": ["Кожевникова Алина Ивановна", "Иванов Иван Иванович"], "respectful": ["Кожевникова Алина Ивановна"], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Львова Анастасия Фёдоровна"], "isClassDataFilled": true}, "1ab99b3a-a19d-4bb1-b59e-b037eaa6ab1d": {"name": "asdf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "1aea266a-704c-449b-b9a8-04983af9eb2d": {"name": "124", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "462c1817-78d6-4514-ab6e-42c72a8ebc02": {"name": "test", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "54bca87b-06f1-4636-9d0b-5c1e23fbe96a": {"name": "asdf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "7f98040d-7619-4a92-b3be-9e21b81cfc04": {"name": "asdf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "8f9598e5-e230-4576-8971-9abba430aeda": {"name": "НЕТВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "ab981c19-92e9-4a4c-b4df-0a14c489cced": {"name": "ЕСТЬВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "b17f87f0-7242-4dae-8415-78976fb2eab1": {"name": "уые", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "03bd1f7f-e140-4909-91b5-c9bf27eba530", "name": "Демо Пользователь"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "fd3d4a52-f734-40f4-80ae-b430391e15a1": {"name": "adsf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-03-15	{"0f80d9d7-4ced-4792-b01a-69ceb1a85347": {"name": "testest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Львова Анастасия Фёдоровна"], "isClassDataFilled": true}, "48d873b4-f7a7-4e29-a75b-129e8657d4f3": {"name": "123", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "4cd6cb5c-cad7-4044-85d0-8453b16ec187": {"name": "testest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}, {"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "DummyUser"}], "students": [], "fstudents": [], "isClassDataFilled": false}}
00000000-0000-0000-0000-000000000000	2025-03-18	{"059db160-8da8-42c6-b547-d6c852d81a32": {"name": "test", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "de41a530-0298-4f87-96aa-01e6ca805e4a", "name": "fasd"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "0f80d9d7-4ced-4792-b01a-69ceb1a85347": {"name": "testest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "14eb9197-8e87-4529-89a7-53cc38000616": {"name": "adf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "19baa673-b8bd-4af1-af51-20c618007060": {"name": "8А", "absent": {"ORVI": ["Иванов Иван Иванович"], "global": ["Иванов Иван Иванович"], "fstudents": ["Иванов Иван Иванович"], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Иванов Иван Иванович"}], "students": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Рябова Полина Михайловна", "Андреев Георгий Дмитриевич", "Голубева Валерия Романовна", "Симонова Вера Савельевна", "Львова Анастасия Фёдоровна", "Козловский Глеб Тимурович", "Никитин Егор Владимирович", "Лукин Михаил Матвеевич", "Сергеева Алиса Камильевна"], "fstudents": ["Иванов Иван Иванович", "Кожевникова Алина Ивановна", "Львова Анастасия Фёдоровна"], "isClassDataFilled": true}, "1aea266a-704c-449b-b9a8-04983af9eb2d": {"name": "124", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "462c1817-78d6-4514-ab6e-42c72a8ebc02": {"name": "test", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "78addb0a-9f07-4576-b0df-e51648bc3401", "name": "fasdf"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "54bca87b-06f1-4636-9d0b-5c1e23fbe96a": {"name": "asdf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "7f98040d-7619-4a92-b3be-9e21b81cfc04": {"name": "asdf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "ChangeNameDummy2"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "8f9598e5-e230-4576-8971-9abba430aeda": {"name": "НЕТВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "769583fe-a2cc-485c-99b8-eb2b3b9495a9", "name": "321"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "ab981c19-92e9-4a4c-b4df-0a14c489cced": {"name": "ЕСТЬВладелец", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "d64f9b23-4a8a-4c95-aafa-b99558a8578b", "name": "ChangeNameDummy2"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "b17f87f0-7242-4dae-8415-78976fb2eab1": {"name": "уые", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "03bd1f7f-e140-4909-91b5-c9bf27eba530", "name": "Демо Пользователь"}], "students": [], "fstudents": [], "isClassDataFilled": false}, "fd3d4a52-f734-40f4-80ae-b430391e15a1": {"name": "fdsaf", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "03bd1f7f-e140-4909-91b5-c9bf27eba530", "name": "Демо Пользователь"}], "students": ["adsf", "asdf", "fdf"], "fstudents": ["asdf"], "isClassDataFilled": false}}
\.


--
-- Data for Name: schools_invites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_invites (school_id, req_id, req_secret, req_body) FROM stdin;
\.


--
-- Data for Name: schools_invites_archived; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_invites_archived (school_id, req_id, req_secret, req_body, use_time) FROM stdin;
00000000-0000-0000-0000-000000000000	3	860	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-09-27 20:40:22.848867
00000000-0000-0000-0000-000000000000	206988	5848	{"name": "test", "roles": ["teacher", "admin"], "classes": []}	2024-09-27 20:53:59.600002
00000000-0000-0000-0000-000000000000	5	9618	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-10-04 12:33:09.085989
00000000-0000-0000-0000-000000000000	229655	3907	{"name": "Я приглашение", "roles": ["teacher", "admin"], "classes": [{"id": "68a35172-ad26-4a93-ab66-49d647c67ef7", "name": "10Б"}]}	2024-10-04 12:50:12.402713
00000000-0000-0000-0000-000000000000	3	860	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-09-27 20:40:22.848867
00000000-0000-0000-0000-000000000000	206988	5848	{"name": "test", "roles": ["teacher", "admin"], "classes": []}	2024-09-27 20:53:59.600002
00000000-0000-0000-0000-000000000000	5	9618	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-10-04 12:33:09.085989
00000000-0000-0000-0000-000000000000	229655	3907	{"name": "Я приглашение", "roles": ["teacher", "admin"], "classes": [{"id": "68a35172-ad26-4a93-ab66-49d647c67ef7", "name": "10Б"}]}	2024-10-04 12:50:12.402713
64e40f2f-2bba-484f-bf95-00ae047ca171	396671	8175	{"name": "Шакирова Резеда Нурисламовна", "roles": ["teacher"], "classes": []}	2024-11-02 11:42:22.127199
00000000-0000-0000-0000-000000000000	3	860	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-09-27 20:40:22.848867
00000000-0000-0000-0000-000000000000	206988	5848	{"name": "test", "roles": ["teacher", "admin"], "classes": []}	2024-09-27 20:53:59.600002
00000000-0000-0000-0000-000000000000	5	9618	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-10-04 12:33:09.085989
00000000-0000-0000-0000-000000000000	229655	3907	{"name": "Я приглашение", "roles": ["teacher", "admin"], "classes": [{"id": "68a35172-ad26-4a93-ab66-49d647c67ef7", "name": "10Б"}]}	2024-10-04 12:50:12.402713
64e40f2f-2bba-484f-bf95-00ae047ca171	396671	8175	{"name": "Шакирова Резеда Нурисламовна", "roles": ["teacher"], "classes": []}	2024-11-02 11:42:22.127199
00000000-0000-0000-0000-000000000000	3	860	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-09-27 20:40:22.848867
00000000-0000-0000-0000-000000000000	206988	5848	{"name": "test", "roles": ["teacher", "admin"], "classes": []}	2024-09-27 20:53:59.600002
00000000-0000-0000-0000-000000000000	5	9618	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}	2024-10-04 12:33:09.085989
00000000-0000-0000-0000-000000000000	229655	3907	{"name": "Я приглашение", "roles": ["teacher", "admin"], "classes": [{"id": "68a35172-ad26-4a93-ab66-49d647c67ef7", "name": "10Б"}]}	2024-10-04 12:50:12.402713
64e40f2f-2bba-484f-bf95-00ae047ca171	396671	8175	{"name": "Шакирова Резеда Нурисламовна", "roles": ["teacher"], "classes": []}	2024-11-02 11:42:22.127199
00000000-0000-0000-0000-000000000000	764528	1750	{"name": "125125", "roles": ["teacher", "admin"], "classes": [{"id": "48d873b4-f7a7-4e29-a75b-129e8657d4f3", "name": "123"}]}	2025-03-16 13:43:53.400166
\.


--
-- Data for Name: schools_template_classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_template_classes (school_id, template_body) FROM stdin;
00000000-0000-0000-0000-000000000000	{"name": null, "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
64e40f2f-2bba-484f-bf95-00ae047ca171	{"name": null, "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
\.


--
-- Data for Name: schools_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_users (school_id, user_id, roles) FROM stdin;
00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	{teacher,admin}
64e40f2f-2bba-484f-bf95-00ae047ca171	96ff9707-cdee-46e9-a0d3-e30e772cf416	{teacher,admin}
00000000-0000-0000-0000-000000000000	03bd1f7f-e140-4909-91b5-c9bf27eba530	{teacher,admin}
00000000-0000-0000-0000-000000000000	d64f9b23-4a8a-4c95-aafa-b99558a8578b	{teacher,admin}
00000000-0000-0000-0000-000000000000	769583fe-a2cc-485c-99b8-eb2b3b9495a9	{teacher}
00000000-0000-0000-0000-000000000000	614b5107-b43d-483b-98cf-3b30c8c7e35b	{teacher,admin}
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, school_id, login, password, name) FROM stdin;
ac7d9df6-9141-461b-bd12-f59370fb9826	00000000-0000-0000-0000-000000000000	2d8c6239b1c794eb508bcee1ecce75eb8c32ff05d23e611c8fc67c35c6df5719	$2a$06$L6lwzXIDBBUXTCmQC4a44e50xg8mtjf9COw/i0ZfgIqbN9KVKSIuK	Иванов Иван Иванович
96ff9707-cdee-46e9-a0d3-e30e772cf416	64e40f2f-2bba-484f-bf95-00ae047ca171	0f8ef3377b30fc47f96b48247f463a726a802f62f3faa03d56403751d2f66c67	$2a$06$JLnrBveP8DJKIeASUlt.nOtXNf5oI4K5esv4iafD8zjL0I/dkDkFm	Юлия Александровна
03bd1f7f-e140-4909-91b5-c9bf27eba530	00000000-0000-0000-0000-000000000000	a0c84f99015cbd714fe2e58ec9eb9e8f4e93a02a058b34ac368ec09fd4be0c59	$2a$06$OJ3JHBgJAF/vW/EUeiI1seJIhJd4VqtYAtoDRIh8f3n0mu8HFRczi	Демо Пользователь
d64f9b23-4a8a-4c95-aafa-b99558a8578b	00000000-0000-0000-0000-000000000000	1a71f4efd61c5759ce2fde1ac0cdb830128270ee8355727ba698c2487c588a47	$2a$06$XDxswnCpidnGsJBFzXJBhObmY.h8g4n2wseN1iSbTl6OSHeAt2dly	ChangeNameDummy2
769583fe-a2cc-485c-99b8-eb2b3b9495a9	00000000-0000-0000-0000-000000000000	043066daf2109523a7490d4bfad4766da5719950a2b5f96d192fc0537e84f32a	$2a$06$mMgW5VMQbm47vwZ9GxtYh.L3T17fcT6TeD3NMWW.rFKOObodskS4u	321
614b5107-b43d-483b-98cf-3b30c8c7e35b	00000000-0000-0000-0000-000000000000	56c5217ae98b6ce3a1929e90d9620722f39e78fb3641a55c45928b71b0e36aa8	$2a$06$uwpMt9Q/q9T3DfG5TbCGjeYnhh1.xG.zcR1kIAJHS6CphQ3H3XM..	afdasdf
\.


--
-- Data for Name: users_salts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_salts (user_id, salt) FROM stdin;
bd10f251-db64-4092-b0b1-2f2fbfc5f768	$2a$06$NVsMVg7xwVYFaSc14Lznxu
6657cbe7-0d5c-4592-8cc7-997e26bb143b	$2a$06$ilqHggpKZ9S4cb.ZEWxFy.
a58e750a-63ca-47f5-837e-502c8d6c227c	$2a$06$fJ4D6iPjuQJBVXwYAwxgCO
ac7d9df6-9141-461b-bd12-f59370fb9826	$2a$06$L6lwzXIDBBUXTCmQC4a44e
03bd1f7f-e140-4909-91b5-c9bf27eba530	$2a$06$OJ3JHBgJAF/vW/EUeiI1se
d64f9b23-4a8a-4c95-aafa-b99558a8578b	$2a$06$XDxswnCpidnGsJBFzXJBhO
96ff9707-cdee-46e9-a0d3-e30e772cf416	$2a$06$JLnrBveP8DJKIeASUlt.nO
769583fe-a2cc-485c-99b8-eb2b3b9495a9	$2a$06$mMgW5VMQbm47vwZ9GxtYh.
614b5107-b43d-483b-98cf-3b30c8c7e35b	$2a$06$uwpMt9Q/q9T3DfG5TbCGje
\.


--
-- Name: schools_change_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.schools_change_logs_id_seq', 227, true);


--
-- Name: schools pk_school_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT pk_school_id PRIMARY KEY (id);


--
-- Name: users pk_user_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT pk_user_id PRIMARY KEY (id);


--
-- Name: schools_users school_user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_users
    ADD CONSTRAINT school_user_roles_pkey PRIMARY KEY (school_id, user_id);


--
-- Name: schools_change_logs schools_change_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_change_logs
    ADD CONSTRAINT schools_change_logs_pkey PRIMARY KEY (id);


--
-- Name: schools_classes_ownership schools_classes_ownership_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_pkey PRIMARY KEY (school_id, user_id, class_id);


--
-- Name: schools_classes_ownership schools_classes_ownership_school_id_user_id_class_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_school_id_user_id_class_id_key UNIQUE (school_id, user_id, class_id);


--
-- Name: schools_classes schools_classes_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes
    ADD CONSTRAINT schools_classes_pk UNIQUE (school_id, class_id);


--
-- Name: schools_classes schools_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes
    ADD CONSTRAINT schools_classes_pkey PRIMARY KEY (school_id, class_id);


--
-- Name: schools_data schools_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_data
    ADD CONSTRAINT schools_data_pkey PRIMARY KEY (school_id, date);


--
-- Name: schools_invites schools_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites
    ADD CONSTRAINT schools_invites_pkey PRIMARY KEY (school_id, req_id);


--
-- Name: schools_template_classes schools_template_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_template_classes
    ADD CONSTRAINT schools_template_classes_pkey PRIMARY KEY (school_id);


--
-- Name: users uniq_login; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uniq_login UNIQUE (login);


--
-- Name: schools_invites unique_sch_id_and_req_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites
    ADD CONSTRAINT unique_sch_id_and_req_id UNIQUE (school_id, req_secret);


--
-- Name: users_salts users_salts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users_salts
    ADD CONSTRAINT users_salts_pkey PRIMARY KEY (user_id);


--
-- Name: idx_school_id_and_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_school_id_and_date ON public.schools_data USING btree (school_id, date);


--
-- Name: users fk_school_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_school_id FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_invites fk_school_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites
    ADD CONSTRAINT fk_school_id FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_users school_user_roles_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_users
    ADD CONSTRAINT school_user_roles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE;


--
-- Name: schools_users school_user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_users
    ADD CONSTRAINT school_user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: schools_classes_ownership schools_classes_ownership_school_id_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_school_id_class_id_fkey FOREIGN KEY (school_id, class_id) REFERENCES public.schools_classes(school_id, class_id);


--
-- Name: schools_classes_ownership schools_classes_ownership_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_classes_ownership schools_classes_ownership_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: schools_classes schools_classes_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes
    ADD CONSTRAINT schools_classes_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_data schools_data_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_data
    ADD CONSTRAINT schools_data_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_invites_archived schools_invites_archived_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites_archived
    ADD CONSTRAINT schools_invites_archived_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: TABLE schools; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools TO floatyapi;


--
-- Name: TABLE schools_change_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE public.schools_change_logs TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE schools_classes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_classes TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE schools_classes_ownership; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_classes_ownership TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE schools_classes_ownership_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_classes_ownership_view TO floatyapi;


--
-- Name: TABLE schools_data; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools_data TO floatyapi;


--
-- Name: TABLE schools_invites; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_invites TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE schools_invites_archived; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_invites_archived TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE schools_template_classes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools_template_classes TO floatyapi;


--
-- Name: TABLE schools_users; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_users TO floatyapi WITH GRANT OPTION;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO floatyapi;


--
-- Name: TABLE users_salts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users_salts TO floatyapi;


--
-- PostgreSQL database dump complete
--

