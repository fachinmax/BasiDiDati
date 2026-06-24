-- domains

CREATE DOMAIN d_person_id AS CHAR(16) CONSTRAINT ck_codice_fiscale CHECK (VALUE ~ '^[A-Z]{6}[0-9]{2}[A-EHLMPR-T][0-9]{2}[A-Z][0-9]{3}[A-Z]$');
CREATE DOMAIN d_email AS VARCHAR(100) CONSTRAINT ck_formato_email CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
CREATE DOMAIN d_phone AS VARCHAR(13) CONSTRAINT ck_formato_telefono CHECK (VALUE ~ '^(\+?39)?[0-9]{10}$');
CREATE DOMAIN d_student_id AS INTEGER CONSTRAINT ck_matricola_positiva CHECK (VALUE >= 0);
CREATE DOMAIN d_address AS VARCHAR(100) CONSTRAINT ck_formato_indirizzo CHECK (VALUE ~* '^(Via|Piazza|Largo|Viale|Corso|Vicolo)\s.+,\s[0-9]+(,\s[Pp]iano\s(-1|[0-9]+))?$');
CREATE DOMAIN d_time_slot AS VARCHAR(7) CONSTRAINT ck_fasce_orarie CHECK (LOWER(VALUE) IN ('prima', 'seconda', 'terza', 'quarta'));
CREATE DOMAIN d_floor AS INTEGER CONSTRAINT ck_piano_valido CHECK (VALUE >= -1);
CREATE DOMAIN d_person_name AS VARCHAR(50) CONSTRAINT ck_nome_persona CHECK (VALUE ~* '^[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9\s]+$');
CREATE DOMAIN d_general_name AS VARCHAR(100);



-- tables

CREATE TABLE Docente (
  cf d_person_id CONSTRAINT pk_docente_cf PRIMARY KEY,
  nome d_person_name NOT NULL,
  cognome d_person_name NOT NULL,
  email d_email NOT NULL CONSTRAINT unq_docente_email UNIQUE,
  telefono d_phone NOT NULL
);

CREATE TABLE Studente (
  cf d_person_id CONSTRAINT pk_studente PRIMARY KEY,
  nome d_person_name NOT NULL,
  cognome d_person_name NOT NULL,
  email d_email NOT NULL CONSTRAINT unq_studente_email UNIQUE,
  matricola d_student_id NOT NULL CONSTRAINT unq_student_matricola UNIQUE
);

CREATE TABLE Corso_di_Laurea (
  nome d_general_name CONSTRAINT pk_cdl_nome PRIMARY KEY,
  n_iscritti INTEGER NOT NULL DEFAULT 0,
  responsabile d_person_id CONSTRAINT fk_cdl_responsabile REFERENCES Docente ON UPDATE CASCADE ON DELETE NO ACTION
);

CREATE TABLE Iscritto (
  studente d_person_id CONSTRAINT fk_iscritto_studente REFERENCES Studente ON UPDATE CASCADE ON DELETE CASCADE,
  corso_di_laurea d_general_name CONSTRAINT fk_iscritto_cdl REFERENCES Corso_di_Laurea ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT pk_iscritto PRIMARY KEY (studente, corso_di_laurea)
);

CREATE TABLE Corso (
  nome d_general_name,
  corso_di_laurea d_general_name CONSTRAINT fk_corso_cdl REFERENCES Corso_di_Laurea ON UPDATE CASCADE ON DELETE CASCADE,
  docente d_person_id NOT NULL CONSTRAINT fk_corso_docente REFERENCES Docente ON UPDATE CASCADE ON DELETE NO ACTION,
  CONSTRAINT pk_corso PRIMARY KEY (nome, corso_di_laurea)
);

CREATE TABLE Edificio (
  nome d_general_name CONSTRAINT pk_edificio PRIMARY KEY,
  indirizzo d_address NOT NULL CONSTRAINT unq_edificio_indirizzo UNIQUE,
  telefono d_phone NOT NULL CONSTRAINT unq_edificio_telefono UNIQUE,
  corso_di_laurea d_general_name CONSTRAINT fk_edificio REFERENCES Corso_di_Laurea ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TABLE Aula (
  nome d_general_name,
  edificio d_general_name CONSTRAINT fk_aula REFERENCES Edificio ON UPDATE CASCADE ON DELETE CASCADE,
  piano d_floor NOT NULL,
  num_posti INTEGER NOT NULL,
  CONSTRAINT pk_aula PRIMARY KEY (nome, edificio)
);

CREATE TABLE Lezione (
  corso d_general_name,
  corso_di_laurea d_general_name,
  giorno DATE,
  fascia_oraria d_time_slot,
  aula d_general_name NOT NULL,
  edificio d_general_name NOT NULL,
  CONSTRAINT pk_lezione PRIMARY KEY (corso, corso_di_laurea, giorno, fascia_oraria),
  CONSTRAINT unq_lezione_giorno_ora_aula_edificio UNIQUE (giorno, fascia_oraria, aula, edificio),
  CONSTRAINT fk_lezione_corso FOREIGN KEY (corso, corso_di_laurea) REFERENCES Corso ON UPDATE CASCADE ON DELETE NO ACTION,
  CONSTRAINT fk_lezione_aula FOREIGN KEY (aula, edificio) REFERENCES Aula ON UPDATE CASCADE ON DELETE CASCADE
);