--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

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
-- Name: class_absent_amount_drop(uuid, uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_absent_amount_drop(IN _orgref uuid, IN _userref uuid, IN _classref uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	update schools_classes set class_body = jsonb_set(
		class_body,
		'{absent_amount}'::text[],
		to_jsonb(0::integer)
	)
	where school_id = _orgRef
	and teacher_id = _userRef
	and class_id = _classRef;
END;
$$;


ALTER PROCEDURE public.class_absent_amount_drop(IN _orgref uuid, IN _userref uuid, IN _classref uuid) OWNER TO postgres;

--
-- Name: class_absent_amount_set(uuid, uuid, uuid, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_absent_amount_set(IN _orgref uuid, IN _userref uuid, IN _classref uuid, IN _new_absent_amount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	update schools_classes set class_body = jsonb_set(
		class_body,
		'{absent_amount}'::text[],
		to_jsonb(_new_absent_amount::integer)
	)
	where school_id = _orgRef
	and teacher_id = _userRef
	and class_id = _classRef;
END;
$$;


ALTER PROCEDURE public.class_absent_amount_set(IN _orgref uuid, IN _userref uuid, IN _classref uuid, IN _new_absent_amount integer) OWNER TO postgres;

--
-- Name: class_amount_drop(uuid, uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_amount_drop(IN _orgref uuid, IN _userref uuid, IN _classref uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	update schools_classes set class_body = jsonb_set(
		class_body,
		'{amount}'::text[],
		to_jsonb(0::integer)
	)
	where school_id = _orgRef
	and teacher_id = _userRef
	and class_id = _classRef;
END;
$$;


ALTER PROCEDURE public.class_amount_drop(IN _orgref uuid, IN _userref uuid, IN _classref uuid) OWNER TO postgres;

--
-- Name: class_amount_get(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_amount_get(_orgref uuid, _userref uuid, _classref uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
	return (
		select class_body->>'amount' from schools_classes 
		where school_id = _orgRef
		and teacher_id = _userRef
		and class_id = _classRef
	)::integer;
END;
$$;


ALTER FUNCTION public.class_amount_get(_orgref uuid, _userref uuid, _classref uuid) OWNER TO postgres;

--
-- Name: class_amount_set(uuid, uuid, uuid, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_amount_set(IN _orgref uuid, IN _userref uuid, IN _classref uuid, IN _new_amount integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
	update schools_classes set class_body = jsonb_set(
		class_body,
		'{amount}'::text[],
		to_jsonb(_new_amount::integer)
	)
	where school_id = _orgRef
	and teacher_id = _userRef
	and class_id = _classRef;
END;
$$;


ALTER PROCEDURE public.class_amount_set(IN _orgref uuid, IN _userref uuid, IN _classref uuid, IN _new_amount integer) OWNER TO postgres;

--
-- Name: class_create(uuid, uuid, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_create(IN _orgref uuid, IN _teacherref uuid, IN _class_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
template_class_body jsonb;
BEGIN

		select template_body into template_class_body from schools_template_classes
			WHERE school_id = _orgRef;
		template_class_body := (select jsonb_set(
			template_class_body,
			'{name}'::text[],
			to_jsonb(_class_name))
);

		insert into schools_classes(school_id, user_id, class_body) VALUES (
			_orgRef,
			_teacherRef,
			template_class_body
		);
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

		return jsonb_build_object('absent_lists', data_root->'absent_lists');
	else
		return 	jsonb_build_object('absent_lists', null);
END if;
END;
$$;


ALTER FUNCTION public.class_data_get(_schoolid uuid, _classid uuid, _date date) OWNER TO postgres;

--
-- Name: class_data_insert(uuid, uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb)
    LANGUAGE plpgsql
    AS $$
declare
	class_body_keys text[];
	key text;
	class_body jsonb;
	object_name text;
BEGIN
	if (select 1 from schools_data 
			where school_id = _schoolID
			and date = CURRENT_DATE) THEN
	ELSE
		RAISE notice 'Data isnot exists for school: %. Generating', _schoolID;
		CALL school_data_gen(_schoolid);
	END IF;
	class_body = (select data->_classID::text from schools_data where date = current_date);
	
	if not(class_body is null) then

	object_name := (select 'absent_lists');
	
	-- iterates with key (cause_type)
		for key in 
			select jsonb_object_keys(class_body->object_name)
			LOOP
				IF (select _input->object_name ? key) THEN


					IF (select jsonb_array_length(_input->object_name->key) != 0) then

		-- setting input into array
						class_body := jsonb_set(
							class_body, 
							('{'::text || object_name || ','::text || key || '}'::text)::text[],
							_input->object_name->key
						);

		-- setting num of fios from input into object_amounts
						class_body := jsonb_set(
							class_body, 
							('{'::text || 'absent_amounts' || ','::text || key || '}'::text)::text[],
							to_jsonb(jsonb_array_length(_input->object_name->key))
						);
					END IF;
				else raise NOTICE 'Key doesnt exists in list-input: %', key;
				END IF;
			END LOOP;

	-- SETING INTO TABLE
		update schools_data set data = jsonb_set(
					data,
					('{'::text || _classID::text || '}'::text)::text[],
					class_body
		) 
			where school_id = _schoolID 
			and date = CURRENT_DATE;
		raise notice '[BODY]: %', class_body;
	ELSE
		RAISE notice 'Can not read class_body for class: %. Is it exists?', _classID;
	END IF;
		
END;
$$;


ALTER PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb) OWNER TO postgres;

--
-- Name: class_drop(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_drop(IN _orgref uuid, IN _class_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes where school_id = _orgRef AND class_id = _class_id) THEN
		DELETE from schools_classes where school_id = _orgRef AND class_id = _class_id;
	END IF;
END;
$$;


ALTER PROCEDURE public.class_drop(IN _orgref uuid, IN _class_id uuid) OWNER TO postgres;

--
-- Name: class_fstudents_add(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_fstudents_add(IN _orgref uuid, IN _teacherref uuid, IN _class_id uuid, IN fstudents text[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    existing_fstudents jsonb;
    new_fstudents jsonb;
    updated_fstudents jsonb;
BEGIN
    IF (SELECT 1 FROM schools_classes
			WHERE school_id = _orgRef
			AND user_id = _userRef
			AND class_id = _class_id) THEN
        -- Get the existing fstudents array
        SELECT class_body->'list_fstudents' INTO existing_fstudents
        FROM schools_classes
        WHERE school_id = _orgRef AND user_id = _userRef AND class_id = _class_id;

        -- Convert the new fstudents array to jsonb
        new_fstudents := to_jsonb(fstudents);

        -- Combine and deduplicate the arrays
        SELECT jsonb_agg(DISTINCT elem) INTO updated_fstudents
        FROM (
            SELECT jsonb_array_elements(existing_fstudents) AS elem
            UNION
            SELECT jsonb_array_elements(new_fstudents) AS elem
        ) combined_elements;

        -- Update the array in the table
        UPDATE schools_classes
        SET class_body = jsonb_set(class_body, '{list_fstudents}', updated_fstudents)
        WHERE school_id = _orgRef AND user_id = _userRef AND class_id = _class_id;
    ELSE
        RAISE NOTICE 'No such class :(';
    END IF;
END;
$$;


ALTER PROCEDURE public.class_fstudents_add(IN _orgref uuid, IN _teacherref uuid, IN _class_id uuid, IN fstudents text[]) OWNER TO postgres;

--
-- Name: class_fstudents_drop(uuid, uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_fstudents_drop(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes 
		where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef) 
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_fstudents}'::text[],
			'[]'::jsonb
		) where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %', 
			_orgRef, 
			_teacherRef, 
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_fstudents_drop(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid) OWNER TO postgres;

--
-- Name: class_fstudents_get(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_fstudents_get(_orgref uuid, _teacherref uuid, _classref uuid) RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
BEGIN
	return QUERY select jsonb_array_elements_text(class_body->'list_fstudents') from schools_classes 
		where school_id = _orgRef AND user_id = _teacherRef and class_id = _classRef;
END;
$$;


ALTER FUNCTION public.class_fstudents_get(_orgref uuid, _teacherref uuid, _classref uuid) OWNER TO postgres;

--
-- Name: class_fstudents_remove(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_fstudents_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _fstudents text[])
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes
		where school_id = _orgRef
		AND user_id = _teacherRef
		AND class_id = _classRef)
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_fstudents}'::text[],
			(
				SELECT CASE
                WHEN jsonb_agg(TStudent) IS NULL THEN '[]'::jsonb
                ELSE jsonb_agg(TStudent)
                END
            FROM jsonb_array_elements_text(class_body->'list_fstudents') AS TStudent
            WHERE TStudent != ALL (_fstudents)
			)
		) where school_id = _orgRef
		AND user_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %',
			_orgRef,
			_teacherRef,
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_fstudents_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _fstudents text[]) OWNER TO postgres;

--
-- Name: class_fstudents_set(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_fstudents_set(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _fstudents text[])
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes 
		where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef) 
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_fstudents}'::text[],
			to_jsonb(_fstudents)
		) where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %', 
			_orgRef, 
			_teacherRef, 
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_fstudents_set(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _fstudents text[]) OWNER TO postgres;

--
-- Name: class_name_get(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_name_get(_orgref uuid, _teacherref uuid, _classref uuid) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
	return (select class_name from schools_classes where school_id = _orgRef 
				AND teacher_id = _teacherRef
				AND class_id = _classRef);
END;
$$;


ALTER FUNCTION public.class_name_get(_orgref uuid, _teacherref uuid, _classref uuid) OWNER TO postgres;

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
-- Name: class_students_add(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_add(IN _orgref uuid, IN _teacherref uuid, IN _class_id uuid, IN students text[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    existing_students jsonb;
    new_students jsonb;
    updated_students jsonb;
BEGIN
    IF (SELECT 1 FROM schools_classes
			WHERE school_id = _orgRef
			AND user_id = _teacherRef
			AND class_id = _class_id) THEN
        -- Get the existing students array
        SELECT class_body->'list_students' INTO existing_students
        FROM schools_classes
        WHERE school_id = _orgRef AND user_id = _teacherRef AND class_id = _class_id;

        -- Convert the new students array to jsonb
        new_students := to_jsonb(students);

        -- Combine and deduplicate the arrays
        SELECT jsonb_agg(DISTINCT elem) INTO updated_students
        FROM (
            SELECT jsonb_array_elements(existing_students) AS elem
            UNION
            SELECT jsonb_array_elements(new_students) AS elem
        ) combined_elements;

        -- Update the array in the table
        UPDATE schools_classes
        SET class_body = jsonb_set(class_body, '{list_students}', updated_students)
        WHERE school_id = _orgRef AND user_id = _teacherRef AND class_id = _class_id;
    ELSE
        RAISE NOTICE 'No such class :(';
    END IF;
END;
$$;


ALTER PROCEDURE public.class_students_add(IN _orgref uuid, IN _teacherref uuid, IN _class_id uuid, IN students text[]) OWNER TO postgres;

--
-- Name: class_students_drop(uuid, uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_drop(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes 
		where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef) 
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_students}'::text[],
			'[]'::jsonb
		) where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %', 
			_orgRef, 
			_teacherRef, 
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_students_drop(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid) OWNER TO postgres;

--
-- Name: class_students_get(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_students_get(_orgref uuid, _teacherref uuid, _classref uuid) RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$
BEGIN
	return QUERY select jsonb_array_elements_text(class_body->'list_students') from schools_classes 
		where school_id = _orgRef AND user_id = _teacherRef and class_id = _classRef;
END;
$$;


ALTER FUNCTION public.class_students_get(_orgref uuid, _teacherref uuid, _classref uuid) OWNER TO postgres;

--
-- Name: class_students_remove(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[])
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes
		where school_id = _orgRef
		AND user_id = _teacherRef
		AND class_id = _classRef)
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_students}'::text[],
			(
				SELECT CASE
                WHEN jsonb_agg(TStudent) IS NULL THEN '[]'::jsonb
                ELSE jsonb_agg(TStudent)
                END
            FROM jsonb_array_elements_text(class_body->'list_students') AS TStudent
            WHERE TStudent != ALL (_students)
			)
		) where school_id = _orgRef
		AND user_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %',
			_orgRef,
			_teacherRef,
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_students_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[]) OWNER TO postgres;

--
-- Name: class_students_set(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_set(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[])
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF (select 1 from schools_classes 
		where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef) 
	THEN
		update schools_classes set class_body = jsonb_set(
			class_body,
			'{list_students}'::text[],
			to_jsonb(_students)
		) where school_id = _orgRef 
		AND teacher_id = _teacherRef
		AND class_id = _classRef;
	ELSE
		RAISE notice 'No such class for school: %, user: %, class: %', 
			_orgRef, 
			_teacherRef, 
			_classRef;
	END IF;

END;
$$;


ALTER PROCEDURE public.class_students_set(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[]) OWNER TO postgres;

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
	if (select 1 from schools_classes where
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
-- Name: is_user_has_role(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_user_has_role(_orgid uuid, _userid uuid, _role text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools where id = _orgID and members->_userID::text->'roles' ? _role) THEN
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
-- Name: school_class_students_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_class_students_get(_orgid uuid, _classid uuid) RETURNS TABLE(class_id uuid, class_lists jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
	if (select 1 from schools_classes where school_id = _orgID and schools_classes.class_id = _classID) then
		return query (select schools_classes.class_id, 

		jsonb_build_object(
			'list_students', class_body->'list_students',
			'list_fstudents', class_body->'list_fstudents',
			'name', class_body->'name'
		)
			from schools_classes where school_id = _orgID and schools_classes.class_id = _classID);

		
	END IF;
END;
$$;


ALTER FUNCTION public.school_class_students_get(_orgid uuid, _classid uuid) OWNER TO postgres;

--
-- Name: school_classes_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_classes_get(_orgid uuid) RETURNS TABLE(class_id uuid, class_body jsonb)
    LANGUAGE plpgsql
    AS $$
begin 
	if (select 1 from schools where id = _orgID) then
		return query (
select sch_classes.class_id, 
			(jsonb_build_object(
				'name', sch_classes.class_body->'name',
				'amount', sch_classes.class_body->'amount',
				'list_students', sch_classes.class_body->'list_students',
				'list_fstudents', sch_classes.class_body->'list_fstudents',
				'owner', jsonb_build_object(
							'id', sch_classes.user_id,
							'name', (select name from users where id = sch_classes.user_id and school_id = _orgID)
				)
			))
from schools_classes as sch_classes where school_id = _orgID);
	end if;
end;
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
    AS $$
DECLARE
	rec RECORD;
    root_new_data jsonb := '{}';
BEGIN
	IF (select true from schools_data where school_id = _orgRef AND date = CURRENT_DATE) THEN
		RAISE NOTICE 'DATA IS ALREADY EXISTS';
	ELSE -- Data isnt exists
	-- Iterating through all classes 
		FOR rec IN 
			select class_id, user_id, class_body from schools_classes
			where school_id = _orgRef
		LOOP -- Inserting into root all classes
			root_new_data := jsonb_insert(
				root_new_data, 
				('{' || rec.class_id || '}')::text[],
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
			CURRENT_DATE,
			root_new_data
		);
END IF;

END;
$$;


ALTER PROCEDURE public.school_data_gen(IN _orgref uuid) OWNER TO postgres;

--
-- Name: school_data_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_data_get(_orgid uuid) RETURNS TABLE(class_id text, class_body jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
if (select exists (select 1 from schools_data where school_id = _orgID and date = current_date)) THEN
	return query (
			SELECT key, 
					jsonb_set(
						value,
						'{owner}'::text[],
						jsonb_build_object(
		'name',(select name from users where id = (select user_id from schools_classes where schools_classes.class_id = key::uuid) ),
		'id', (select user_id from schools_classes where schools_classes.class_id = key::uuid)
	)
)
			FROM schools_data, jsonb_each(data)
			WHERE school_id = _orgID
			AND DATE = CURRENT_DATE
			);
END IF;
END;
$$;


ALTER FUNCTION public.school_data_get(_orgid uuid) OWNER TO postgres;

--
-- Name: school_data_get(uuid, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_data_get(_orgid uuid, _date date) RETURNS TABLE(class_id text, class_body jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN

IF (_date is null) THEN
        _date := CURRENT_DATE;
END IF;
if (select true from schools_data where school_id = _orgID and date = _date) THEN
        return query (
                        SELECT key, value
                        FROM schools_data, jsonb_each(data)
                        WHERE school_id = _orgID
                        AND date = _date
                        );
END IF;
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
        SUM((value->>'amount')::integer) AS total_amount,
        value->'absent_lists' AS absent_lists, -- keep the absent_lists for each key
		value->'absent_amounts' AS absent_amounts,
		value->'owner'->'id' as owner_id,
		value->'owner'->'name' as owner_name
    FROM 
        schools_data, 
        jsonb_each(data) AS elements(key, value)
	WHERE
		school_id = _orgID and date between start_date and end_date
    GROUP BY 
        class_name, absent_amounts, absent_lists, owner_name, owner_id, key
)
SELECT 
    jsonb_object_agg(key, jsonb_build_object(
		'name', class_name,
        'amount', total_amount,
        'absent_lists', absent_lists,  -- include the absent_lists
		'absent_amounts', absent_amounts,
		'owner', jsonb_build_object('id', owner_id, 'name', owner_name)
    )) into result
FROM 
    summed_amounts;
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
-- Name: school_title_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_title_get(_orgref uuid) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
	return title from schools where id = _orgRef;
END;
$$;


ALTER FUNCTION public.school_title_get(_orgref uuid) OWNER TO postgres;

--
-- Name: school_user_drop(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_user_drop(IN _orgid uuid, IN _userid uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN

	if (_userref is null) then
		return;
	end if;

   update schools set members =
      (
         SELECT members - _userID::text
      )
		WHERE id = _orgID;
        
update schools_classes set user_id = null
                where school_id = _orgID
                and user_id = _userID;

        delete from users_salts where user_id = _userID;
        delete from users where id = _userID;

END;
$$;


ALTER PROCEDURE public.school_user_drop(IN _orgid uuid, IN _userid uuid) OWNER TO postgres;

--
-- Name: school_users_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_users_get(_orgid uuid) RETURNS TABLE(user_id uuid, user_body jsonb)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        _user_id::uuid,
		jsonb_build_object(
			'name', users.name::text,
			'roles', members -> _user_id -> 'roles',
			'classes',class_info.classes
		)
    FROM 
        schools
    JOIN 
        LATERAL jsonb_object_keys(members) AS _user_id ON TRUE
    JOIN 
        users ON users.id = _user_id::uuid
    LEFT JOIN (
        SELECT 
            class_data.user_id,
            jsonb_agg(jsonb_build_object(class_id, class_name)) AS classes
        FROM (
            SELECT 
                schools_classes.user_id,
                class_id,
                class_body ->> 'name' AS class_name
            FROM 
                schools_classes
        ) AS class_data
        GROUP BY 
            class_data.user_id
    ) AS class_info ON class_info.user_id = users.id  -- Join based on users.id instead
    WHERE 
        schools.id = _orgID;  -- Filtering based on the organization ID
END;
$$;


ALTER FUNCTION public.school_users_get(_orgid uuid) OWNER TO postgres;

--
-- Name: schools_data_get(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.schools_data_get(_orgid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
BEGIN

	if (select exists (select 1 from schools_data where school_id = _orgID and date = current_date)) then
		return (select data from schools_data where school_id = _orgID and date = current_date);
	END IF;
	return null;
END;
$$;


ALTER FUNCTION public.schools_data_get(_orgid uuid) OWNER TO postgres;

--
-- Name: user_classes_degrant(uuid, uuid, uuid[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_classes_degrant(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
 WITH class_ids AS (
        SELECT unnest(_classrefs) AS class_id
    )
    UPDATE schools_classes SET user_id = null
    FROM class_ids
	    WHERE schools_classes.school_id = _schoolRef
	    AND schools_classes.class_id = class_ids.class_id;
END;
$$;


ALTER PROCEDURE public.user_classes_degrant(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[]) OWNER TO postgres;

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

CREATE FUNCTION public.user_classes_get(_orgref uuid, _teacherref uuid) RETURNS TABLE(id uuid, class_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	    RETURN QUERY
    (
		select classes.class_id, classes.class_body->>'name' from schools_classes as classes
			where school_id = _orgref
			and user_id = _teacherref
	);
END;
$$;


ALTER FUNCTION public.user_classes_get(_orgref uuid, _teacherref uuid) OWNER TO postgres;

--
-- Name: user_classes_grant(uuid, uuid, uuid[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_classes_grant(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
 WITH class_ids AS (
        SELECT unnest(_classrefs) AS class_id
    )
    UPDATE schools_classes SET user_id = _userID
    FROM class_ids
	    WHERE schools_classes.school_id = _schoolRef
	    AND schools_classes.class_id = class_ids.class_id;
END;
$$;


ALTER PROCEDURE public.user_classes_grant(IN _schoolref uuid, IN _userid uuid, IN _classrefs uuid[]) OWNER TO postgres;

--
-- Name: user_classes_grant(uuid, uuid, uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_classes_grant(IN _schoolref uuid, IN _userid uuid, IN _classref uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
update schools
        set members = jsonb_set(
                members,
                ('{'::text || _userID::text ||', classes}'::text)::text[],
                (
                        select jsonb_agg(DISTINCT elem) FROM
                                (
                                        select jsonb_array_elements(members->_userID::text->'classes') as elem
                                        UNION
                                        select to_jsonb(_classref::text) as elem
                                )
                )
    )
        where id = _schoolRef;
update schools_classes set user_id = _userID
        where school_id = _schoolref
        and class_id = _classref;
END;
$$;


ALTER PROCEDURE public.user_classes_grant(IN _schoolref uuid, IN _userid uuid, IN _classref uuid) OWNER TO postgres;

--
-- Name: user_classes_id_name_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_classes_id_name_get(_orgref uuid, _teacherref uuid) RETURNS TABLE(id uuid, class_name text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	    RETURN QUERY
    (
		select sch.class_id, sch.class_name 
			from schools_classes as sch
			where school_id = _orgref
			and teacher_id = _teacherref
	);
END;
$$;


ALTER FUNCTION public.user_classes_id_name_get(_orgref uuid, _teacherref uuid) OWNER TO postgres;

--
-- Name: user_create(uuid, text, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_create(IN _orgref uuid, IN _login text, IN _password text, IN _name text)
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


ALTER PROCEDURE public.user_create(IN _orgref uuid, IN _login text, IN _password text, IN _name text) OWNER TO postgres;

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
                UPDATE public.schools
                    SET members = jsonb_set(
                        members,
                        ( '{' || v_user_id::text || '}' )::text[],
                        jsonb_build_object(
                               'roles', _roles,
                               'classes', _classes
                        )::jsonb,
                        true
                        )
                                WHERE id = _orgRef;
ELSE
        RAISE notice 'no such user! %', _userID;
END IF;
      END;
      $$;


ALTER PROCEDURE public.user_create_with_context(IN _orgref uuid, IN _login text, IN _password text, IN _name text, IN _roles text[], IN _classes text[]) OWNER TO postgres;

--
-- Name: user_create_with_roles(uuid, text, text, text, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_create_with_roles(IN _orgref uuid, IN _login text, IN _password text, IN _name text, IN _roles text[])
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
                UPDATE public.schools
                    SET members = jsonb_set(
                        members,
                        ( '{' || v_user_id::text || '}' )::text[],
                        jsonb_build_object(
                               'roles', _roles,
                               'classes', ARRAY[]::text[]
                        )::jsonb,
                        true
                	)
				WHERE id = _orgRef;
ELSE
        RAISE notice 'no such user! %', _userID;
END IF;
      END;
      $$;


ALTER PROCEDURE public.user_create_with_roles(IN _orgref uuid, IN _login text, IN _password text, IN _name text, IN _roles text[]) OWNER TO postgres;

--
-- Name: user_drop(uuid); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_drop(IN _userref uuid)
    LANGUAGE plpgsql
    AS $$
DECLARE
        school_refs uuid[];
        school uuid;
BEGIN
	if (_userref is null) then
		return;
	end if;

        school_refs := (select DISTINCT school_id from users where id = _userRef);
        FOREACH school in array school_refs LOOP
                update schools set members =
                (
                        SELECT members - '_userRef'::text
                )
                WHERE id = school;
        update schools_classes set user_id = uuid_nil()
                where school_id = school
                and teacher_id = _userRef;
        END LOOP;
        delete from users_salts where user_id = _userRef;
        delete from users where id = _userRef;
END;
$$;


ALTER PROCEDURE public.user_drop(IN _userref uuid) OWNER TO postgres;

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
-- Name: user_roles_add(uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_roles_add(IN _orgref uuid, IN _userid uuid, IN _roles text[])
    LANGUAGE plpgsql
    AS $$
       BEGIN

       -- Insert user's data in schools(members)
       IF (select true from public.users where school_id = _orgRef and id = _userID)
       	AND (select true from public.schools where members ? _userID::text) THEN
       	UPDATE public.schools set members = jsonb_set(
       		members,
       		('{' || _userID || ', roles}')::text[],
      			(
      			select jsonb_agg(DISTINCT elem) FROM
      				(
      				select jsonb_array_elements(members->_userID::text->'roles') as elem
      					UNION
      				select jsonb_array_elements(to_jsonb(_roles)) as elem
      				)
      			)
      		)
      	where id = _orgRef;
      ELSE
      	RAISE INFO 'No such user. Is it in schools AND users tables? ID: %', _userID;
      END IF;
      END;
      $$;


ALTER PROCEDURE public.user_roles_add(IN _orgref uuid, IN _userid uuid, IN _roles text[]) OWNER TO postgres;

--
-- Name: user_roles_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_roles_get(_schoolref uuid, _userid uuid) RETURNS SETOF text
    LANGUAGE plpgsql
    AS $$

DECLARE
	userRoles text[];
	userRolesJSONB jsonb;
BEGIN
	userRolesJSONB := (SELECT members->(_userID::text)->>'roles'
			FROM schools 
			WHERE id = _schoolRef);

	RETURN QUERY SELECT elem
                 FROM jsonb_array_elements_text(userRolesJSONB) AS elem;

    -- Если после выполнения запроса не было возвращено ни одной строки, возвращаем пустой набор результатов
    IF NOT FOUND THEN
        RETURN;
    END IF;

END;

$$;


ALTER FUNCTION public.user_roles_get(_schoolref uuid, _userid uuid) OWNER TO postgres;

--
-- Name: user_roles_remove(uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_roles_remove(IN _orgref uuid, IN _userid uuid, IN _roles text[])
    LANGUAGE plpgsql
    AS $$
BEGIN

-- Insert user's data in schools(members)
IF (select true from public.users where school_id = _orgRef and id = _userID)
	AND (select true from public.schools where members ? _userID::text) THEN
	UPDATE public.schools set members = jsonb_set(
		members,
		('{' || _userID || ', roles}')::text[],
			(
				SELECT CASE
                WHEN jsonb_agg(role) IS NULL THEN '[]'::jsonb
                	ELSE jsonb_agg(role)
                END
	            FROM jsonb_array_elements_text(members->_userID::text->'roles') AS role
	            WHERE role != ALL (_roles)
			)
	)
	where id = _orgRef;
ELSE
	RAISE INFO 'No such user. Is it in schools AND users? ID: %', _userID;
END IF;
END;
$$;


ALTER PROCEDURE public.user_roles_remove(IN _orgref uuid, IN _userid uuid, IN _roles text[]) OWNER TO postgres;

--
-- Name: user_roles_set(uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.user_roles_set(IN _orgref uuid, IN _userid uuid, IN _roles text[])
    LANGUAGE plpgsql
    AS $$
       BEGIN

       -- Insert user's data in schools(members)
       IF (select true from public.users where school_id = _orgRef and id = _userID)
       	AND (select true from public.schools where members ? _userID::text) THEN
       	UPDATE public.schools set members = jsonb_set(
       		members,
       		('{' || _userID || ', roles}')::text[],
      			(
      			select jsonb_agg(DISTINCT elem) FROM
      				(
      				select jsonb_array_elements(to_jsonb(_roles)) as elem
      				)
      			)
      		)
      	where id = _orgRef;
      ELSE
      	RAISE INFO 'No such user. Is it in schools AND users tables? ID: %', _userID;
      END IF;
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
-- Name: schools_classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_classes (
    school_id uuid NOT NULL,
    user_id uuid,
    class_id uuid DEFAULT gen_random_uuid() NOT NULL,
    class_body jsonb DEFAULT '{"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}'::jsonb NOT NULL
);


ALTER TABLE public.schools_classes OWNER TO postgres;

--
-- Name: schools_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_data (
    school_id uuid,
    date date,
    data jsonb
);


ALTER TABLE public.schools_data OWNER TO postgres;

--
-- Name: schools_invites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_invites (
    school_id uuid,
    user_id uuid,
    message character varying(255)
);


ALTER TABLE public.schools_invites OWNER TO postgres;

--
-- Name: schools_template_classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schools_template_classes (
    school_id uuid,
    template_body jsonb DEFAULT '{"amount": 0, "absent_count": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "list_fstudents": []}'::jsonb NOT NULL
);


ALTER TABLE public.schools_template_classes OWNER TO postgres;

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
00000000-0000-0000-0000-000000000000	nil	nil	nil	nil	nil	{"ac7d9df6-9141-461b-bd12-f59370fb9826": {"roles": ["tester", "teacher", "admin"], "classes": []}}
64e40f2f-2bba-484f-bf95-00ae047ca171	МБОУ "Гимназия №125"	116	Казань	Советский район	test@gmail.com	{"6657cbe7-0d5c-4592-8cc7-997e26bb143b": {"roles": ["admin", "teacher", "dev"], "classes": []}, "a58e750a-63ca-47f5-837e-502c8d6c227c": {"roles": [], "classes": []}, "bd10f251-db64-4092-b0b1-2f2fbfc5f768": {"roles": ["dev", "teacher"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd"]}, "c419f7f6-ac38-432a-a4b0-54a315f835b2": {"roles": ["admin", "teacher", "dev"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd", "e7a2c4e3-525c-4433-b5d7-9e085d43d661"]}}
\.


--
-- Data for Name: schools_classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_classes (school_id, user_id, class_id, class_body) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	\N	64e1779b-8f5a-4bd0-a6a9-acf58563aa0e	{"name": "10_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
64e40f2f-2bba-484f-bf95-00ae047ca171	c419f7f6-ac38-432a-a4b0-54a315f835b2	96a99d12-9519-4963-a84e-fdc05bfc368d	{"name": "1_А", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
64e40f2f-2bba-484f-bf95-00ae047ca171	c419f7f6-ac38-432a-a4b0-54a315f835b2	91cb7c53-8ea7-4fa3-a4bd-eee234aac918	{"name": "1_Б", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
64e40f2f-2bba-484f-bf95-00ae047ca171	c419f7f6-ac38-432a-a4b0-54a315f835b2	2423b285-eb67-4887-bb60-c081ff3170ac	{"name": "1_В", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	300cf306-33c9-4bbc-996c-c5b2e03997ba	{"name": "99_F", "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
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
00000000-0000-0000-0000-000000000000	2024-07-26	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-07-27	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-07-30	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Tempoev", "Kakov"], "fstudents": ["Ivanov"], "respectful": ["Tempoev"], "not_respectful": ["Kakov"]}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 1}, "list_fstudents": []}}
\.


--
-- Data for Name: schools_invites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_invites (school_id, user_id, message) FROM stdin;
\.


--
-- Data for Name: schools_template_classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_template_classes (school_id, template_body) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	{"name": null, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
00000000-0000-0000-0000-000000000000	{"name": null, "amount": 0, "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, school_id, login, password, name) FROM stdin;
6c041382-180d-4e37-a858-e7a5c2b1c2a6	64e40f2f-2bba-484f-bf95-00ae047ca171	f82578ee7624ea0a1b7a266d33d79095795e5557abaa189076241d3ce9fdd47b	$2a$06$9YNV4M2Wq/hoTYA/dQycrexzOunkahXxugrEKKhpwIxfPefF7n8AG	
bd10f251-db64-4092-b0b1-2f2fbfc5f768	64e40f2f-2bba-484f-bf95-00ae047ca171	sasha	$2a$06$NVsMVg7xwVYFaSc14LznxuAG5/VOERy9aSSC4efTv/M5NS3X2qNXy	devop
00000000-0000-0000-0000-000000000000	00000000-0000-0000-0000-000000000000	nil	nil	nil
c419f7f6-ac38-432a-a4b0-54a315f835b2	64e40f2f-2bba-484f-bf95-00ae047ca171	297581d6cd198a6e6df740f13288cb13a1e76cebe3f0ebc3fe259977addfd646	$2a$06$3a8y1eugKcQkTc9lIN9yWuWd71XJxXqCErxDN76sbDntvUcOR9m4W	Alexandr
a58e750a-63ca-47f5-837e-502c8d6c227c	64e40f2f-2bba-484f-bf95-00ae047ca171	9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08	$2a$06$fJ4D6iPjuQJBVXwYAwxgCOEqJA1hGsIuQK37lfqFm4LlHBBna7I6.	I am the test :)
fd696e3f-fdac-48ad-922e-5164fa50c3a7	64e40f2f-2bba-484f-bf95-00ae047ca171	1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014	$2a$06$TCiKE7hFIVo5bbKdHgYShOn/5bd6P9T4tITmZ4Sy1/vgrR5nPSeUm	I am the test :)
ac7d9df6-9141-461b-bd12-f59370fb9826	00000000-0000-0000-0000-000000000000	2d8c6239b1c794eb508bcee1ecce75eb8c32ff05d23e611c8fc67c35c6df5719	$2a$06$L6lwzXIDBBUXTCmQC4a44e50xg8mtjf9COw/i0ZfgIqbN9KVKSIuK	Tester Floatyev Ivanich
\.


--
-- Data for Name: users_salts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users_salts (user_id, salt) FROM stdin;
6c041382-180d-4e37-a858-e7a5c2b1c2a6	$2a$06$9YNV4M2Wq/hoTYA/dQycre
bd10f251-db64-4092-b0b1-2f2fbfc5f768	$2a$06$NVsMVg7xwVYFaSc14Lznxu
6657cbe7-0d5c-4592-8cc7-997e26bb143b	$2a$06$ilqHggpKZ9S4cb.ZEWxFy.
c419f7f6-ac38-432a-a4b0-54a315f835b2	$2a$06$3a8y1eugKcQkTc9lIN9yWu
a58e750a-63ca-47f5-837e-502c8d6c227c	$2a$06$fJ4D6iPjuQJBVXwYAwxgCO
fd696e3f-fdac-48ad-922e-5164fa50c3a7	$2a$06$TCiKE7hFIVo5bbKdHgYShO
ac7d9df6-9141-461b-bd12-f59370fb9826	$2a$06$L6lwzXIDBBUXTCmQC4a44e
\.


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
-- Name: users uniq_login; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uniq_login UNIQUE (login);


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
-- Name: schools_classes fk_school_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes
    ADD CONSTRAINT fk_school_id FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_data schools_data_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_data
    ADD CONSTRAINT schools_data_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_invites schools_invites_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites
    ADD CONSTRAINT schools_invites_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools_invites schools_invites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_invites
    ADD CONSTRAINT schools_invites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: TABLE schools; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools TO floatyapi;


--
-- Name: TABLE schools_classes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools_classes TO floatyapi;


--
-- Name: TABLE schools_data; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools_data TO floatyapi;


--
-- Name: TABLE schools_invites; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schools_invites TO floatyapi;


--
-- Name: TABLE schools_template_classes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools_template_classes TO floatyapi;


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

