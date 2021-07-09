--
-- PostgreSQL database dump
--

-- Dumped from database version 12.7
-- Dumped by pg_dump version 12.7

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acmedns; Type: TABLE; Schema: public; Owner: testuser
--

CREATE TABLE public.acmedns (
    name text,
    value text
);


ALTER TABLE public.acmedns OWNER TO testuser;

--
-- Name: records; Type: TABLE; Schema: public; Owner: testuser
--

CREATE TABLE public.records (
    username text NOT NULL,
    password text NOT NULL,
    subdomain text NOT NULL,
    allowfrom text
);


ALTER TABLE public.records OWNER TO testuser;

--
-- Name: txt; Type: TABLE; Schema: public; Owner: testuser
--

CREATE TABLE public.txt (
    rowid integer NOT NULL,
    subdomain text NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    lastupdate integer
);


ALTER TABLE public.txt OWNER TO testuser;

--
-- Name: txt_rowid_seq; Type: SEQUENCE; Schema: public; Owner: testuser
--

CREATE SEQUENCE public.txt_rowid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.txt_rowid_seq OWNER TO testuser;

--
-- Name: txt_rowid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: testuser
--

ALTER SEQUENCE public.txt_rowid_seq OWNED BY public.txt.rowid;


--
-- Name: txt rowid; Type: DEFAULT; Schema: public; Owner: testuser
--

ALTER TABLE ONLY public.txt ALTER COLUMN rowid SET DEFAULT nextval('public.txt_rowid_seq'::regclass);


--
-- Data for Name: acmedns; Type: TABLE DATA; Schema: public; Owner: testuser
--

COPY public.acmedns (name, value) FROM stdin;
db_version	1
\.


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: testuser
--

COPY public.records (username, password, subdomain, allowfrom) FROM stdin;
cbfed1bb-c0b9-4b24-b212-5b95caa38f98	$2a$12$VfIgY9Az57bVCuo57/UlVemDrAOCAjc7Z1vE4T.z.lHKbaQhxEtqK	c8d6aeae-3f21-4786-b243-98bbd7c526a5	[]
c6853765-5036-4f01-9325-c7b97ee0fb2e	$2a$12$kav9uwPNxxaI7ydONxHlsuAb3OvE5BNCRRgLJeDxHMprlgv5Yqc8W	2acca63e-1c34-4860-95f3-ba208dd8b0bc	[]
0a59ceba-4648-4b91-b3d0-879160ab5bdf	$2a$12$JUgDd6Up6P5SMdfNszNHSeYjcfSdgwb11XpVu298sk028NCnXH0Zy	773aacab-9539-4d59-b5e6-76718261e078	[]
e3cf6541-81ee-46a6-a2f0-6a2ddd85871e	$2a$12$3kwyAvs9TC09f5hXrjm33uibt.sIF17qMqDy4d6d1H0pwWqN240O.	d70eafbf-fa48-41fd-9496-bb6fa973c535	[]
\.


--
-- Data for Name: records; Type: TABLE DATA; Schema: public; Owner: testuser
--

COPY public.txt (subdomain) FROM stdin;
c8d6aeae-3f21-4786-b243-98bbd7c526a5
2acca63e-1c34-4860-95f3-ba208dd8b0bc
773aacab-9539-4d59-b5e6-76718261e078
d70eafbf-fa48-41fd-9496-bb6fa973c535
\.


--
-- Name: records records_password_key; Type: CONSTRAINT; Schema: public; Owner: testuser
--

ALTER TABLE ONLY public.records
    ADD CONSTRAINT records_password_key UNIQUE (password);


--
-- Name: records records_pkey; Type: CONSTRAINT; Schema: public; Owner: testuser
--

ALTER TABLE ONLY public.records
    ADD CONSTRAINT records_pkey PRIMARY KEY (username);


--
-- Name: records records_subdomain_key; Type: CONSTRAINT; Schema: public; Owner: testuser
--

ALTER TABLE ONLY public.records
    ADD CONSTRAINT records_subdomain_key UNIQUE (subdomain);


--
-- PostgreSQL database dump complete
--

