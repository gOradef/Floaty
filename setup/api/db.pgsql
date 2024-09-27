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
			'list_students', data_root->'list_students',
			'list_fstudents', data_root->'list_fstudents'
		);
	else
		return 	jsonb_build_object('absent', null);
END if;
END;
$$;


ALTER FUNCTION public.class_data_get(_schoolid uuid, _classid uuid, _date date) OWNER TO postgres;

--
-- Name: class_data_insert(uuid, uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb)
    LANGUAGE plpgsql
    AS $$DECLARE
    class_body_keys text[];
    key text;
    class_body jsonb;
    object_name text;
    absent_global jsonb;
BEGIN
    IF (SELECT 1 FROM schools_data 
        WHERE school_id = _schoolID
        AND date = CURRENT_DATE) THEN
        -- Данные существуют, ничего не делаем
    ELSE
        RAISE NOTICE 'Data does not exist for school: %. Generating', _schoolID;
        CALL school_data_gen(_schoolID);
    END IF;

    class_body := (SELECT data -> _classID::text FROM schools_data WHERE date = CURRENT_DATE);
    
    IF NOT (class_body IS NULL) THEN
        object_name := 'absent';
        absent_global := '[]'::jsonb;

        -- Итерация по ключам (cause_type)
        FOR key IN 
            SELECT jsonb_array_elements_text('["ORVI", "respectful", "not_respectful"]')
        LOOP
            IF (_input -> object_name ? key) THEN
                -- Установка значения из входных данных в массив
                class_body := jsonb_set(
                    class_body, 
                    ('{' || object_name || ',' || key || '}')::text[], -- Путь для установки значения
                    _input -> object_name -> key -- Значение из входных данных
                );

                -- Объединение существующих глобальных значений с текущими значениями из _input
                absent_global := (
                    WITH data AS (
                        SELECT 
                            (absent_global)::jsonb AS array1,
                            (_input -> object_name -> key)::jsonb AS array2
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
                ('{' || object_name || ', global}')::text[], -- Путь к глобальному значению
                absent_global
            );
        ELSE
            class_body := jsonb_set(
                class_body,
                ('{' || object_name || ', global}')::text[],
                '[]'::jsonb -- Установка в null, если массив пуст
            );
        END IF;
        
        -- Установка isClassDataFilled в true
        class_body := jsonb_set(
            class_body, 
            '{isClassDataFilled}'::text[], -- Путь для установки isClassDataFilled
            'true'::jsonb, -- Новое значение
            true -- Перезаписать, если существует
        );

        -- УСТАНОВКА В ТАБЛИЦУ
        UPDATE schools_data SET data = jsonb_set(
            data,
            ('{'::text || _classID::text || '}'::text)::text[],
            class_body
        ) 
        WHERE school_id = _schoolID 
        AND date = CURRENT_DATE;

        RAISE NOTICE '[BODY]: %', class_body;
    ELSE
        RAISE NOTICE 'Cannot read class_body for class: %. Does it exist?', _classID;
    END IF;
END;$$;


ALTER PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb) OWNER TO postgres;

--
-- Name: class_data_insert(uuid, uuid, jsonb, date); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_data_insert(IN _schoolid uuid, IN _classid uuid, IN _input jsonb, IN _date date)
    LANGUAGE plpgsql
    AS $$DECLARE
    class_body_keys text[];
    key text;
    class_body jsonb;
    object_name text;
    absent_global jsonb;
BEGIN
    IF (SELECT 1 FROM schools_data
        WHERE school_id = _schoolID
        AND date = _date) THEN
        -- Данные существуют, ничего не делаем
    ELSE
		RETURN;
    END IF;

    class_body := (SELECT data -> _classID::text FROM schools_data WHERE date = _date);

    IF NOT (class_body IS NULL) THEN
        object_name := 'absent';
        absent_global := '[]'::jsonb;

        -- Итерация по ключам (cause_type)
        FOR key IN
            SELECT jsonb_array_elements_text('["ORVI", "respectful", "not_respectful"]')
        LOOP
            IF (_input -> object_name ? key) THEN
                -- Установка значения из входных данных в массив
                class_body := jsonb_set(
                    class_body,
                    ('{' || object_name || ',' || key || '}')::text[], -- Путь для установки значения
                    _input -> object_name -> key -- Значение из входных данных
                );

			-- 
                -- Объединение существующих глобальных значений с текущими значениями из _input 
                absent_global := (
                    WITH data AS (
                        SELECT
                            (absent_global)::jsonb AS array1,
                            (_input -> object_name -> key)::jsonb AS array2
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
                ('{' || object_name || ', global}')::text[], -- Путь к глобальному значению
                absent_global
            );
        ELSE
            class_body := jsonb_set(
                class_body,
                ('{' || object_name || ', global}')::text[],
                '[]'::jsonb -- Установка в null, если массив пуст
            );
        END IF;

        -- Установка isClassDataFilled в true
        class_body := jsonb_set(
            class_body,
            '{isClassDataFilled}'::text[], -- Путь для установки isClassDataFilled
            'true'::jsonb, -- Новое значение
            true -- Перезаписать, если существует
        );

        -- УСТАНОВКА В ТАБЛИЦУ
        UPDATE schools_data SET data = jsonb_set(
            data,
            ('{'::text || _classID::text || '}'::text)::text[],
            class_body
        )
        WHERE school_id = _schoolID
        AND date = _date;

        RAISE NOTICE '[BODY]: %', class_body;
    ELSE
        RAISE NOTICE 'Cannot read class_body for class: %. Does it exist?', _classID;
    END IF;
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
-- Name: class_props_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.class_props_get(_orgid uuid, _classid uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
	return jsonb_build_object(
		'id', _classID,
		'name', (select class_body->'name' from schools_classes 
			where school_id = _orgID
			and class_id = _classID),
		'students', (select class_body->'students' from schools_classes 
			where school_id = _orgID
			and class_id = _classID),
		'fstudents', (select class_body->'fstudents' from schools_classes 
		where school_id = _orgID
		and class_id = _classID)
	);
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
        -- Get the existing students array
        SELECT class_body->'list_students' INTO existing_students
        FROM schools_classes_ownership_view
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
        WHERE school_id = _orgRef AND class_id = _class_id;
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

CREATE FUNCTION public.class_students_get(_school_id uuid, _user_id uuid, _class_id uuid) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
begin
		return (select jsonb_build_object(
			'students', class_body->'students',
			'fstudents', class_body->'fstudents'
		) from schools_classes_ownership_view where
			school_id = _school_id
			and class_id = _class_id
			and user_id = _user_id
		);
end;
$$;


ALTER FUNCTION public.class_students_get(_school_id uuid, _user_id uuid, _class_id uuid) OWNER TO postgres;

--
-- Name: class_students_remove(uuid, uuid, uuid, text[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.class_students_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[])
    LANGUAGE plpgsql
    AS $$
BEGIN
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
	AND class_id = _classRef;
END;
$$;


ALTER PROCEDURE public.class_students_remove(IN _orgref uuid, IN _teacherref uuid, IN _classref uuid, IN _students text[]) OWNER TO postgres;

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
-- Name: school_class_students_get(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_class_students_get(_school_id uuid, _class_id uuid) RETURNS jsonb
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


ALTER FUNCTION public.school_class_students_get(_school_id uuid, _class_id uuid) OWNER TO postgres;

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
            summed_amounts sa
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
            'absent', fa.absent,  -- include the absent_lists
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
-- Name: school_invite_create(uuid, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.school_invite_create(IN _school_id uuid, IN _req_body jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
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
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', u_class_id,
                        'name', (
                            SELECT class_body->>'name' 
                            FROM schools_classes
                            WHERE school_id = _school_id
                            AND class_id = u_class_id::uuid  -- Ensure you have the correct type for class_id
                        )
                    )
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
-- Name: school_invite_props_get(uuid, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.school_invite_props_get(_orgref uuid, _req_id text, _req_secret text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$begin
	if (select exists (select 1 from schools_invites
		where school_id = _orgref
		and req_id = _req_id
		and req_secret = _req_secret)) then
		return req_body from schools_invites
		where school_id = _orgref
		and req_id = _req_id
		and req_secret = _req_secret;
	end if;
	return null;
end;$$;


ALTER FUNCTION public.school_invite_props_get(_orgref uuid, _req_id text, _req_secret text) OWNER TO postgres;

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
		select jsonb_agg(
			jsonb_build_object(
				'id', classes.class_id,
				'name', classes.class_body->'name'
			))
		from schools_classes_ownership_view as classes
			where school_id = _orgref
			and user_id = _teacherref
	);
END;
$$;


ALTER FUNCTION public.user_classes_get(_orgref uuid, _teacherref uuid) OWNER TO postgres;

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

		  INSERT INTO public.schools_users(school_id, user_id, roles)
		  VALUES(_orgRef, v_user_id, _roles);
		  
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
	if (_userRef is null) then
		return;
	end if;

        school_refs := (select DISTINCT school_id from users where id = _userRef);
        FOREACH school in array school_refs LOOP
        update schools_classes_ownerhip set user_id = uuid_nil()
                where school_id = school
                and teacher_id = _userRef;
        END LOOP;
        delete from users_salts where user_id = _userRef;
        delete from users where id = _userRef;
		delete from schools_users where user_id = _userRef;
		delete from schools_classes_ownership where user_id = _userRef;
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
BEGIN
	userRoles := (SELECT roles
			FROM schools_users 
				WHERE school_id = _schoolRef
				AND user_id = _userID);

	RETURN QUERY (select unnest(userRoles));

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
-- Name: result; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.result (
    jsonb_object_agg jsonb
);


ALTER TABLE public.result OWNER TO postgres;

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
-- Data for Name: result; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.result (jsonb_object_agg) FROM stdin;
{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["3124", "431"], "global": ["124", "3124", "431"], "respectful": ["124"]}, "amount": null, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"]}, "4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "123", "absent": {"ORVI": ["Tester", "Tester2"], "global": ["Tester", "Tester2"]}, "amount": null, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"]}, "7f309bfe-bb9f-4338-b370-1cb27824ae15": {"name": "12_А", "absent": {"ORVI": ["123", "321", "4123"], "global": ["123", "321", "4123"]}, "amount": null, "owners": [], "students": ["123", "321", "4123"]}, "a57ec99f-71c6-480d-8d91-525d43af4ea3": {"name": "10_А", "absent": {"global": ["4124"], "not_respectful": ["4124"]}, "amount": null, "owners": [], "students": ["4124", "12412", "531"]}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": ["ыегв1"], "global": ["stud32", "ыегв1"], "respectful": ["stud32"]}, "amount": null, "owners": [], "students": ["ыегв1", "stud2", "stud32"]}}
\.


--
-- Data for Name: schools; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools (id, title, region, city, area, email, members) FROM stdin;
64e40f2f-2bba-484f-bf95-00ae047ca171	МБОУ "Гимназия №125"	116	Казань	Советский район	test@gmail.com	{"6657cbe7-0d5c-4592-8cc7-997e26bb143b": {"roles": ["admin", "teacher", "dev"], "classes": []}, "a58e750a-63ca-47f5-837e-502c8d6c227c": {"roles": [], "classes": []}, "bd10f251-db64-4092-b0b1-2f2fbfc5f768": {"roles": ["dev", "teacher"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd"]}, "c419f7f6-ac38-432a-a4b0-54a315f835b2": {"roles": ["admin", "teacher", "dev"], "classes": ["c9195fac-94f1-4cf1-b687-7fcf8abccbbd", "e7a2c4e3-525c-4433-b5d7-9e085d43d661"]}}
00000000-0000-0000-0000-000000000000	nil	nil	nil	nil	nil	{"82b4b650-1f1d-4868-be93-0bc98b1c5190": {"roles": [], "classes": []}, "934ced4e-ee81-4b21-96c7-fd6a67aaf19f": {"roles": ["teacher"], "classes": ["e3ec4a16-365a-4b6d-ac3f-79182df83701"]}, "ac7d9df6-9141-461b-bd12-f59370fb9826": {"roles": ["tester", "teacher", "admin"], "classes": []}, "c7bf75c9-2426-42e0-9cc0-47b8eb1d34d5": {"roles": ["apitest1", "teacher"], "classes": ["e3ec4a16-365a-4b6d-ac3f-79182df83701"]}, "ff856428-37b2-4c21-a1d7-ed647b514e27": {"roles": [], "classes": []}}
\.


--
-- Data for Name: schools_classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_classes (school_id, class_id, class_body) FROM stdin;
00000000-0000-0000-0000-000000000000	3fb6418a-50d5-4e0d-8c6d-b65aae5a2417	{"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	62e4c1af-29b7-4d6d-861e-2b18b6e2d8c6	{"name": "4А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	c02c7d4b-f98e-498c-80e2-9e120387ac16	{"name": "4Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	68a35172-ad26-4a93-ab66-49d647c67ef7	{"name": "10Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": [], "fstudents": []}
00000000-0000-0000-0000-000000000000	e0ffe1e4-febc-41c6-953e-3b5efa6151b7	{"name": "1_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"]}
00000000-0000-0000-0000-000000000000	b1f991d6-db76-4271-9d65-0fd918a78cd6	{"name": "5_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["123", "321", "512"], "fstudents": []}
00000000-0000-0000-0000-000000000000	27341434-81a3-4fb9-9ef0-5ea700595e06	{"name": "10А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["3124", "124", "431"], "fstudents": []}
00000000-0000-0000-0000-000000000000	49648214-0209-4525-8b18-01c42f7a5a1c	{"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "students": ["1"], "fstudents": []}
\.


--
-- Data for Name: schools_classes_ownership; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_classes_ownership (school_id, user_id, class_id) FROM stdin;
00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	27341434-81a3-4fb9-9ef0-5ea700595e06
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
00000000-0000-0000-0000-000000000000	2024-08-07	{"300cf306-33c9-4bbc-996c-c5b2e03997ba": {"name": "99_F", "owner": {"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, "amount": 0, "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Tempoev", "Kakov"], "fstudents": ["Ivanov"], "respectful": ["Tempoev"], "not_respectful": ["Kakov"]}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 1}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-08-10	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov1"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-09-01	{"08514837-d0ab-406e-8583-2c950e120287": {"name": "098", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "c5cb143c-b3de-4d00-ae61-25ef75b082c6": {"name": "etstsetsetsetest", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 22, "owners": [], "list_students": ["Efimov"], "list_fstudents": [], "isClassDataFilled": false}, "d910deba-6d6c-4b77-a97b-44bbb1ea634a": {"name": "testClass#3", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 4, "owners": [{"id": "82ef00ca-96bc-48b2-8eac-d0768a4ece81", "name": "Юлия Александровна"}, {"id": "934ced4e-ee81-4b21-96c7-fd6a67aaf19f", "name": "api-test"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "e12f4928-aa63-41e1-8bd8-d508ccf0e6e0": {"name": "naturalClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 25, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Egorov"], "list_fstudents": ["Egorov"], "isClassDataFilled": false}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": [], "list_fstudents": [], "isClassDataFilled": false}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5", "Efimov", "1", "2", "3", "4", "5", "6", "7", "8", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "list_fstudents": ["Ivanov5", "Ivanov4", "Ivanov3", "asdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd fasdklfj al;sdjf l;akjsdf l;kjas;dlfj al;skjd f"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-09-25	{"27341434-81a3-4fb9-9ef0-5ea700595e06": {"name": "10А", "absent": {"ORVI": ["124"], "global": ["124", "431"], "fstudents": [], "respectful": [], "not_respectful": ["431"]}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["3124", "124", "431"], "fstudents": [], "isClassDataFilled": true}, "3fb6418a-50d5-4e0d-8c6d-b65aae5a2417": {"name": "4_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "49648214-0209-4525-8b18-01c42f7a5a1c": {"name": "8_А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["1"], "fstudents": [], "isClassDataFilled": false}, "62e4c1af-29b7-4d6d-861e-2b18b6e2d8c6": {"name": "4А", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "68a35172-ad26-4a93-ab66-49d647c67ef7": {"name": "10Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "b1f991d6-db76-4271-9d65-0fd918a78cd6": {"name": "5_А", "absent": {"ORVI": ["321", "123"], "global": ["321", "123", "512"], "fstudents": [], "respectful": ["512"], "not_respectful": []}, "owners": [], "students": ["123", "321", "512"], "fstudents": [], "isClassDataFilled": true}, "c02c7d4b-f98e-498c-80e2-9e120387ac16": {"name": "4Б", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": [], "fstudents": [], "isClassDataFilled": false}, "e0ffe1e4-febc-41c6-953e-3b5efa6151b7": {"name": "1_А", "absent": {"ORVI": ["stud2", "stud32"], "global": ["stud2", "stud32"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["ыегв1", "stud2", "stud32"], "fstudents": ["stud32"], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-14	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-09-19	{"4f9ab221-bd07-4fc9-9baa-8c49853a645c": {"name": "123", "absent": {"ORVI": ["Tester2"], "global": ["Tester2"], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "students": ["Tester", "Tester2"], "fstudents": ["Tester"], "isClassDataFilled": true}, "bace629b-6b03-4505-9403-a87b5df7e926": {"name": "removeAmountClass", "absent": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "owners": [], "students": ["123"], "fstudents": [], "isClassDataFilled": true}}
00000000-0000-0000-0000-000000000000	2024-08-16	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}, {"id": "c7bf75c9-2426-42e0-9cc0-47b8eb1d34d5", "name": "api-test"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
00000000-0000-0000-0000-000000000000	2024-08-19	{"6c42c322-d434-4639-ae0e-8eb29088dc33": {"name": "test1", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "e3ec4a16-365a-4b6d-ac3f-79182df83701": {"name": "test2", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": [], "global": [], "fstudents": [], "respectful": [], "not_respectful": []}, "list_students": [], "absent_amounts": {"ORVI": 0, "global": 0, "fstudents": 0, "respectful": 0, "not_respectful": 0}, "list_fstudents": []}, "f501a40b-acd6-4b6e-8428-cb52707f4f94": {"name": "test3", "amount": 0, "owners": [{"id": "ac7d9df6-9141-461b-bd12-f59370fb9826", "name": "Tester Floatyev Ivanich"}], "absent_lists": {"ORVI": ["Ivanov"], "global": ["Ivanov", "Setkov", "Adminov"], "fstudents": ["Setkov"], "respectful": ["Adminov"], "not_respectful": []}, "list_students": ["Ivanov0", "Ivanov1", "Ivanov2", "Ivanov3", "Ivanov4", "Ivanov5"], "absent_amounts": {"ORVI": 1, "global": 3, "fstudents": 1, "respectful": 1, "not_respectful": 0}, "list_fstudents": []}}
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
\.


--
-- Data for Name: schools_invites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schools_invites (school_id, req_id, req_secret, req_body) FROM stdin;
00000000-0000-0000-0000-000000000000	3	860	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}
00000000-0000-0000-0000-000000000000	4	435	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}
00000000-0000-0000-0000-000000000000	5	9618	{"name": "api-test", "roles": ["teacher"], "classes": [{"id": "e3ec4a16-365a-4b6d-ac3f-79182df83701", "name": "test2"}]}
00000000-0000-0000-0000-000000000000	998248	8982	{"name": "123", "roles": ["teacher", "admin"], "classes": null}
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
00000000-0000-0000-0000-000000000000	00000000-0000-0000-0000-000000000000	{1,teacher,admin,test}
00000000-0000-0000-0000-000000000000	82ef00ca-96bc-48b2-8eac-d0768a4ece81	{teacher,admin}
00000000-0000-0000-0000-000000000000	934ced4e-ee81-4b21-96c7-fd6a67aaf19f	{teacher,admin}
00000000-0000-0000-0000-000000000000	ac7d9df6-9141-461b-bd12-f59370fb9826	{teacher,admin}
00000000-0000-0000-0000-000000000000	0e5fe7b3-8002-48be-80a8-e62bd32aefb9	{teacher}
00000000-0000-0000-0000-000000000000	626de5e5-2d13-4f66-80be-402641a05265	{teacher}
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, school_id, login, password, name) FROM stdin;
6c041382-180d-4e37-a858-e7a5c2b1c2a6	64e40f2f-2bba-484f-bf95-00ae047ca171	f82578ee7624ea0a1b7a266d33d79095795e5557abaa189076241d3ce9fdd47b	$2a$06$9YNV4M2Wq/hoTYA/dQycrexzOunkahXxugrEKKhpwIxfPefF7n8AG	
00000000-0000-0000-0000-000000000000	00000000-0000-0000-0000-000000000000	nil	nil	nil
c419f7f6-ac38-432a-a4b0-54a315f835b2	64e40f2f-2bba-484f-bf95-00ae047ca171	297581d6cd198a6e6df740f13288cb13a1e76cebe3f0ebc3fe259977addfd646	$2a$06$3a8y1eugKcQkTc9lIN9yWuWd71XJxXqCErxDN76sbDntvUcOR9m4W	Alexandr
fd696e3f-fdac-48ad-922e-5164fa50c3a7	64e40f2f-2bba-484f-bf95-00ae047ca171	1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014	$2a$06$TCiKE7hFIVo5bbKdHgYShOn/5bd6P9T4tITmZ4Sy1/vgrR5nPSeUm	I am the test :)
ac7d9df6-9141-461b-bd12-f59370fb9826	00000000-0000-0000-0000-000000000000	2d8c6239b1c794eb508bcee1ecce75eb8c32ff05d23e611c8fc67c35c6df5719	$2a$06$L6lwzXIDBBUXTCmQC4a44e50xg8mtjf9COw/i0ZfgIqbN9KVKSIuK	Tester Floatyev Ivanich
ff856428-37b2-4c21-a1d7-ed647b514e27	00000000-0000-0000-0000-000000000000	811f1895d782af1ef9bf4d42d1710878ff47b2ba6768e914ca7c8220c97f2572	$2a$06$F7QFfmA.70gde5jf/GlMQ.Fzq86CaZIZVyP7PosiuxdNrKNToFnfW	Victorovich
934ced4e-ee81-4b21-96c7-fd6a67aaf19f	00000000-0000-0000-0000-000000000000	7117476ce4f850bfa18c365922a07b7e4347eef8057c3bbaf14442cc3b1e625d	$2a$06$Y.kwOC7gCZAtlcgqMPGRC.6yYyOJf39PCwq.YeDs4ISmqKZjLTo2q	api-test
82b4b650-1f1d-4868-be93-0bc98b1c5190	00000000-0000-0000-0000-000000000000	123	$2a$06$IqR5XqMqT9bu4n6wWNeR1.PwJnMnI/.1ECjCFR7oCaEny5/4O3M96	123
82ef00ca-96bc-48b2-8eac-d0768a4ece81	00000000-0000-0000-0000-000000000000	0f8ef3377b30fc47f96b48247f463a726a802f62f3faa03d56403751d2f66c67	$2a$06$6s3yGfIcbfKE/bQenSOuaOnFfI3CwQv8jQhG/5SM3L5Bv1Ii65Iz2	Юлия Александровна
0e5fe7b3-8002-48be-80a8-e62bd32aefb9	00000000-0000-0000-0000-000000000000	932f3c1b56257ce8539ac269d7aab42550dacf8818d075f0bdf1990562aae3ef	$2a$06$bJ5ZMKGsmNFtBN2h5MkJtOFsrkbvbT6lxZsFnBK0TJVItsnVslCmy	api-test
626de5e5-2d13-4f66-80be-402641a05265	00000000-0000-0000-0000-000000000000	96cae35ce8a9b0244178bf28e4966c2ce1b8385723a96a6b838858cdd6ca0a1e	$2a$06$DtbVi4uikMb4beNC3.1Vv.2w198tyTTbXdyPhDByvXCfV0jqkfw5q	api-test
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
ff856428-37b2-4c21-a1d7-ed647b514e27	$2a$06$F7QFfmA.70gde5jf/GlMQ.
934ced4e-ee81-4b21-96c7-fd6a67aaf19f	$2a$06$Y.kwOC7gCZAtlcgqMPGRC.
82b4b650-1f1d-4868-be93-0bc98b1c5190	$2a$06$IqR5XqMqT9bu4n6wWNeR1.
82ef00ca-96bc-48b2-8eac-d0768a4ece81	$2a$06$6s3yGfIcbfKE/bQenSOuaO
0e5fe7b3-8002-48be-80a8-e62bd32aefb9	$2a$06$bJ5ZMKGsmNFtBN2h5MkJtO
626de5e5-2d13-4f66-80be-402641a05265	$2a$06$DtbVi4uikMb4beNC3.1Vv.
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
-- Name: schools_users school_user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_users
    ADD CONSTRAINT school_user_roles_pkey PRIMARY KEY (school_id, user_id);


--
-- Name: schools_classes_ownership schools_classes_ownership_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schools_classes_ownership
    ADD CONSTRAINT schools_classes_ownership_pkey PRIMARY KEY (school_id, user_id, class_id);


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
-- Name: TABLE schools; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.schools TO floatyapi;


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

