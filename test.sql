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



-- triggers

-- vincolo integrita' 4: un docente non puo' essere anche uno studente e, viceversa, uno studente non puo' essere anche un docente

CREATE FUNCTION check_student_is_not_teacher()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS
$$
  BEGIN
    PERFORM *
    FROM Docente
    WHERE cf = NEW.cf OR email = NEW.email;
    
    IF FOUND THEN
      RAISE EXCEPTION '[ERROR][STUDENT]: l''email % o codice fiscale % identifica un docente.', NEW.email, NEW.cf;
      RETURN NULL;
    END IF;
    
    RETURN NEW;
  END;
$$;

CREATE TRIGGER trg_student_disjoint_check_ins
BEFORE INSERT ON Studente
FOR EACH ROW
EXECUTE FUNCTION check_student_is_not_teacher();

CREATE TRIGGER trg_student_disjoint_check_upd
BEFORE UPDATE OF cf, email ON Studente
FOR EACH ROW
WHEN (OLD.cf IS DISTINCT FROM NEW.cf OR OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION check_student_is_not_teacher();


CREATE FUNCTION check_teacher_is_not_student()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS
$$
  BEGIN
    PERFORM *
    FROM Studente
    WHERE cf = NEW.cf OR email = NEW.email;
    
    IF FOUND THEN
      RAISE EXCEPTION '[ERROR][TEACHER]: l''email % o codice fiscale % identifica uno studente.', NEW.email, NEW.cf;
      RETURN NULL;
    END IF;
    
    RETURN NEW;
  END;
$$;

CREATE TRIGGER trg_teacher_disjoint_check_ins
BEFORE INSERT ON Docente
FOR EACH ROW
EXECUTE FUNCTION check_teacher_is_not_student();

CREATE TRIGGER trg_teacher_disjoint_check_update
BEFORE UPDATE OF cf, email ON Docente
FOR EACH ROW
WHEN (OLD.cf IS DISTINCT FROM NEW.cf OR OLD.email IS DISTINCT FROM NEW.email)
EXECUTE FUNCTION check_teacher_is_not_student();


-- vincolo integrita' 5: ogni studente deve essere iscritto ad almeno un corso di laurea.
--                       La rimozione di tutte le iscrizioni di uno studente deve comportare la sua rimozione.

CREATE OR REPLACE FUNCTION check_student_enrolled()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS
$$
  BEGIN
    PERFORM *
    FROM Iscritto
    WHERE studente = NEW.cf;

    IF NOT FOUND THEN
      RAISE EXCEPTION '[ERROR][STUDENT]: lo studente % deve essere iscritto in almeno un corso di laurea', NEW.cf;
      RETURN NULL;
    END IF;

    RETURN NEW;
  END;
$$;

CREATE CONSTRAINT TRIGGER trg_student_must_be_enrolled_ins
AFTER INSERT ON Studente
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW
EXECUTE FUNCTION check_student_enrolled();


CREATE OR REPLACE FUNCTION remove_students_del()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS $$
  BEGIN
    IF NOT EXISTS (SELECT * FROM Iscritto WHERE studente = OLD.studente) THEN
      DELETE FROM Studente WHERE cf = OLD.studente;
    END IF;
      
    RETURN OLD;
  END;
$$;

CREATE TRIGGER trg_student_must_be_enrolled_del
AFTER DELETE ON Iscritto
FOR EACH ROW
EXECUTE FUNCTION remove_students_del();


CREATE OR REPLACE FUNCTION remove_students_update()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS $$
  BEGIN
    IF NOT EXISTS (SELECT * FROM Iscritto WHERE studente = OLD.studente) THEN
      DELETE FROM Studente WHERE cf = OLD.studente;
    END IF;
      
    RETURN NEW;
  END;
$$;

CREATE TRIGGER trg_student_must_be_enrolled_update
BEFORE UPDATE OF studente ON Iscritto
FOR EACH ROW
WHEN (OLD.studente IS DISTINCT FROM NEW.studente)
EXECUTE FUNCTION remove_students_update();


-- ridondanza sul attributo n iscritti

CREATE OR REPLACE FUNCTION update_student_count()
RETURNS TRIGGER
LANGUAGE PLPGSQL AS
$$
  BEGIN
    IF (TG_OP = 'INSERT') THEN
      UPDATE Corso_di_Laurea SET n_iscritti = n_iscritti + 1 WHERE nome = NEW.corso_di_laurea;

    ELSIF (TG_OP = 'DELETE') THEN
      UPDATE Corso_di_Laurea SET n_iscritti = n_iscritti - 1 WHERE nome = OLD.corso_di_laurea;

    ELSIF (TG_OP = 'UPDATE') THEN
      UPDATE Corso_di_Laurea SET n_iscritti = n_iscritti - 1 WHERE nome = OLD.corso_di_laurea;
      UPDATE Corso_di_Laurea SET n_iscritti = n_iscritti + 1 WHERE nome = NEW.corso_di_laurea;
    END IF;

    RETURN NULL;
  END;
$$;

CREATE TRIGGER trg_enrollment_count_ins_del
AFTER INSERT OR DELETE ON Iscritto
FOR EACH ROW
EXECUTE FUNCTION update_student_count();

CREATE TRIGGER trg_enrollment_count_upd
AFTER UPDATE OF corso_di_laurea ON Iscritto
FOR EACH ROW
WHEN (OLD.corso_di_laurea IS DISTINCT FROM NEW.corso_di_laurea)
EXECUTE FUNCTION update_student_count();


-- popolamento

INSERT INTO Docente (cf, nome, cognome, email, telefono) VALUES
('PZZCRL99P15L219X', 'Carla', 'Piazza', 'a.piazza@stud.it', '+392345437687'),
('RSSMRA80A01H501U', 'Mario', 'Rossi', 'mario.rossi@uniud.it', '+390612345673'),
('BNCGNN75T10F205Z', 'Giovanna', 'Bianchi', 'g.bianchi@uniud.it', '0298765432'),
('VRDLCU82P15L219X', 'Luca', 'Verdi', 'l.verdi@uniud.it', '3331234567'),
('GLLFRC70E20H501A', 'Federica', 'Gialli', 'f.gialli@uniud.it', '+390817654321'),
('NRSMRA65M12L117D', 'Maria', 'Neri', 'm.neri@uniud.it', '0112233445'),
('BRBDRN88S04H501Q', 'Adriano', 'Barba', 'a.barba@uniud.it', '3471122334'),
('CRSRRT77B14F205P', 'Roberto', 'Corso', 'r.corso@uniud.it', '0519988776'),
('LBRFNC90D22H501L', 'Francesca', 'Libri', 'f.libri@uniud.it', '+393391234567'),
('MNTLRA85H08L219K', 'Laura', 'Monti', 'l.monti@uniud.it', '0105566778'),
('SLVSTR72A01F205W', 'Stefano', 'Silvestri', 's.silvestri@uniud.it', '0699001122'),
('FRRMRC78L12F205S', 'Marco', 'Ferrari', 'm.ferrari@uniud.it', '+390212343567'),
('RSSSRA82P15H501V', 'Sara', 'Russo', 'sara.russo@uniud.it', '+390119988776'),
('GLIAND88S04L219R', 'Andrea', 'Galli', 'a.galli@uniud.it', '+393043381188'),
('CRSRRT75M12F205T', 'Rita', 'Corso', 'rit.corso@uniud.it', '+390501667788'),
('BRNMTT90D22H501N', 'Mattia', 'Bruno', 'm.bruno@uniud.it', '0493344556'),
('VLLFNC84A01L219J', 'Francesca', 'Villa', 'f.villa@uniud.it', '+390433776655'),
('RZZGNN79T10F205K', 'Giovanni', 'Rizzo', 'g.rizzo@uniud.it', '+390815542433'),
('LOMMRA81H08H501X', 'Maria', 'Lombardi', 'm.lombardi@uniud.it', '0382112233'),
('PSTSTF73A01F205Q', 'Stefano', 'Pasti', 's.pasti@uniud.it', '0559988112');

START TRANSACTION;
INSERT INTO Corso_di_Laurea (nome, n_iscritti, responsabile) VALUES 
('Informatica', 0, 'PZZCRL99P15L219X'),
('Internet of Things, Big Data, Machine Learning', 0, 'PZZCRL99P15L219X'),
('Tecnologie digitali e comunicazione per le industrie creative', 0, 'VRDLCU82P15L219X'),
('Fisica', 0, 'GLLFRC70E20H501A'),
('Matematica', 0, 'NRSMRA65M12L117D'),
('Artificial Intelligence & Cybersecurity', 0, 'BRBDRN88S04H501Q');

INSERT INTO Corso (nome, corso_di_laurea, docente) VALUES 
('Basi di Dati', 'Informatica', 'PZZCRL99P15L219X'),
('Programmazione', 'Informatica', 'SLVSTR72A01F205W'),
('Ingegneria Software', 'Informatica', 'RSSMRA80A01H501U'),
('Analisi', 'Informatica', 'SLVSTR72A01F205W'),
('Informatica per l''Industria Creativa', 'Tecnologie digitali e comunicazione per le industrie creative', 'SLVSTR72A01F205W'),
('Logica', 'Informatica', 'SLVSTR72A01F205W'),
('Calcolo Scientifico', 'Informatica', 'RSSMRA80A01H501U'),
('Architettura', 'Informatica', 'RSSMRA80A01H501U'),
('Analisi ', 'Informatica', 'NRSMRA65M12L117D'),
('Matematica e Statistica', 'Tecnologie digitali e comunicazione per le industrie creative', 'VRDLCU82P15L219X'),
('Sociologia della comunicazione', 'Tecnologie digitali e comunicazione per le industrie creative', 'VLLFNC84A01L219J'),
('Dinamica', 'Fisica', 'GLLFRC70E20H501A'),
('Geometria', 'Matematica', 'NRSMRA65M12L117D'),
('Logica', 'Matematica', 'NRSMRA65M12L117D'),
('Advanced topics in AI I', 'Artificial Intelligence & Cybersecurity', 'BRBDRN88S04H501Q'),
('Analisi Numerica', 'Matematica', 'CRSRRT77B14F205P'),
('Deep learning', 'Artificial Intelligence & Cybersecurity', 'LBRFNC90D22H501L'),
('Machine Learning', 'Internet of Things, Big Data, Machine Learning', 'MNTLRA85H08L219K'),
('Basi di Dati', 'Internet of Things, Big Data, Machine Learning', 'PZZCRL99P15L219X');
COMMIT;

START TRANSACTION;
INSERT INTO Edificio (nome, indirizzo, telefono, corso_di_laurea) VALUES
('Rizzi', 'Via delle Scienze, 206', '0611122233', 'Informatica'),
('Aule Feruglio', 'Via delle Scienze, 212, piano 0', '0644455566', 'Informatica'),
('Edificio A', 'Via Roma, 10, piano 0', '0433898298', 'Fisica'),
('Edificio B', 'Largo Leonardo, 1, piano -1', '0432455566', 'Fisica'),
('Edificio C', 'Piazza Newton, 5, piano 0', '0212345678', 'Fisica'),
('Edificio Le Aquile', 'Corso Pasteur, 8', '0115566778', 'Tecnologie digitali e comunicazione per le industrie creative'),
('Edificio Copernico', 'Piazza Provola, 8, piano 1', '0115566738', 'Tecnologie digitali e comunicazione per le industrie creative'),
('Edificio Torre', 'Corso Carducci, 28', '4534576435', 'Internet of Things, Big Data, Machine Learning'),
('Polo Giuliano', 'Largo Ippocrate, 2, piano -1', '0677889900', 'Matematica'),
('Villa Mirafiori', 'Via Aristotele, 45, piano 0', '0644332211', 'Matematica'),
('Torre Archimede', 'Piazza Pitagora, 1, piano 1', '0498877665', 'Matematica'),
('Edificio Conte', 'Via Cogito, 1, piano 0', '2340987894', 'Artificial Intelligence & Cybersecurity');

INSERT INTO Aula (nome, edificio, piano, num_posti) VALUES 
('C1', 'Rizzi', -1, 200),
('C2', 'Rizzi', -1, 140),
('C3', 'Rizzi', -1, 300),
('C4', 'Rizzi', -1, 250),
('E-20', 'Edificio Conte', 2, 240),
('E-21', 'Edificio Conte', 2, 240),
('E-22', 'Edificio Conte', 2, 240),
('Aula Magna', 'Edificio Le Aquile', 0, 300),
('Aula Big', 'Edificio Le Aquile', 0, 300),
('Aula Small', 'Edificio Le Aquile', 0, 300),
('Alpha', 'Aule Feruglio', 0, 300),
('Beta', 'Aule Feruglio', 0, 200),
('Gamma', 'Aule Feruglio', 0, 300),
('Aula 1', 'Edificio A', 2, 200),
('Aula 2', 'Edificio A', 2, 200),
('Aula 3', 'Edificio A', 2, 200),
('Aula 4', 'Edificio A', 1, 80),
('Aula 1', 'Edificio Torre', 1, 200),
('Aula 2', 'Edificio Torre', 1, 200),
('Aula 3', 'Edificio Torre', 1, 200),
('Sala 1', 'Villa Mirafiori', 0, 125),
('Sala 4', 'Villa Mirafiori', 0, 100),
('Sala 5', 'Villa Mirafiori', 0, 70),
('Aula 1', 'Edificio B', 1, 80),
('Aula 2', 'Edificio B', 0, 130),
('Aula 3', 'Edificio B', -1, 100),
('Aula 100', 'Edificio C', 1, 80),
('Aula 102', 'Edificio C', 1, 80),
('Aula 101', 'Edificio C', 1, 80),
('Aula Verde', 'Edificio Copernico', 2, 60),
('P1', 'Polo Giuliano', 1, 60),
('P2', 'Polo Giuliano', 1, 60),
('P3', 'Polo Giuliano', 1, 60),
('Aula Informatica 1', 'Torre Archimede', 1, 45),
('Aula Informatica 2', 'Torre Archimede', 1, 45);
COMMIT;

START TRANSACTION;
SET CONSTRAINTS trg_student_must_be_enrolled_ins DEFERRED;

INSERT INTO Studente (cf, nome, cognome, email, matricola) VALUES 
('FRNAND99P15L219X', 'Alessandro', 'Franco', 'a.franco@stud.it', 1001),
('BRTMRA01E20H501A', 'Marta', 'Berti', 'm.berti@stud.it', 1002),
('CRSRST00M12L117D', 'Stefano', 'Crisi', 's.crisi@stud.it', 1003),
('DVLRCC98S04H501Q', 'Riccardo', 'Davoli', 'r.davoli@stud.it', 1004),
('GRCVAL97B14F205P', 'Valentina', 'Greco', 'v.greco@stud.it', 1005),
('LOMFNC96D22H501L', 'Francesco', 'Lombardi', 'f.lombardi@stud.it', 1006),
('MRNAND95H08L219K', 'Andrea', 'Marini', 'a.marini@stud.it', 1007),
('PLMGNN94A01F205W', 'Giovanni', 'Palumbo', 'g.palumbo@stud.it', 1008),
('RZZLRA93T10F205Z', 'Laura', 'Rizzi', 'l.rizzi@stud.it', 1009),
('VLLMRA92A01H501U', 'Marco', 'Villa', 'm.villa@stud.it', 1010),
('BANCRI02E20H501C', 'Cristian', 'Banfi', 'c.banfi@stud.unimi.it', 3001),
('MORLRA98P15L219Z', 'Ilaria', 'Moretti', 'i.moretti@stud.unive.it', 3002),
('GTTSTM00M12L117F', 'Tommaso', 'Gatti', 't.gatti@stud.unibo.it', 3003),
('RSSRCC97S04H501Y', 'Riccardo', 'Russo', 'r.russo@stud.unito.it', 3004),
('FBBVKN96B14F205M', 'Valentina', 'Fabbri', 'v.fabbri@stud.uniroma1.it', 3005),
('LNIFNC95D22H501P', 'Federico', 'Lini', 'f.lini@stud.unipd.it', 3006),
('SNTAND94H08L219T', 'Andrea', 'Santi', 'a.santi@stud.unipi.it', 3007),
('GRDGNN93A01F205U', 'Giovanni', 'Grandi', 'g.grandi@stud.unina.it', 3008),
('MLNLRA92T10F205B', 'Elena', 'Molinari', 'e.molinari@stud.unipv.it', 3009),
('VTTMRA91A01H501L', 'Marta', 'Vetri', 'm.vetri@stud.unifi.it', 3010),
('BRNAND90P15L219Q', 'Alessandro', 'Bruno', 'a.bruno@stud.uniba.it', 3011),
('CASSRA89E20H501D', 'Sara', 'Casadei', 's.casadei@stud.unical.it', 3012),
('DLURST88M12L117G', 'Stefano', 'De Luca', 's.deluca@stud.unime.it', 3013),
('ESPRCC87S04H501W', 'Chiara', 'Esposito', 'c.esposito@stud.unict.it', 3014),
('FRNVAL86B14F205N', 'Valerio', 'Franceschi', 'v.franceschi@stud.unipa.it', 3015),
('GLLFNC85D22H501R', 'Francesca', 'Galli', 'f.galli@stud.uninsubria.it', 3016),
('LMBAND84H08L219V', 'Daniele', 'Lambert', 'd.lambert@stud.univaq.it', 3017),
('MRNGNN83A01F205Z', 'Nicola', 'Marini', 'n.marini@stud.unich.it', 3018),
('NRELCA82T10F205C', 'Alice', 'Neri', 'a.neri@stud.uniurb.it', 3019),
('PLTMRA81A01H501M', 'Marco', 'Pilati', 'm.pilati@stud.unich.it', 3020);

INSERT INTO Iscritto (studente, corso_di_laurea) VALUES
('FRNAND99P15L219X', 'Informatica'),
('BRTMRA01E20H501A', 'Informatica'),
('CRSRST00M12L117D', 'Tecnologie digitali e comunicazione per le industrie creative'),
('DVLRCC98S04H501Q', 'Fisica'),
('GRCVAL97B14F205P', 'Matematica'),
('LOMFNC96D22H501L', 'Artificial Intelligence & Cybersecurity'),
('MRNAND95H08L219K', 'Matematica'),
('MRNAND95H08L219K', 'Fisica'),
('PLMGNN94A01F205W', 'Internet of Things, Big Data, Machine Learning'),
('RZZLRA93T10F205Z', 'Internet of Things, Big Data, Machine Learning'),
('VLLMRA92A01H501U', 'Internet of Things, Big Data, Machine Learning'),
('BANCRI02E20H501C', 'Informatica'),
('MORLRA98P15L219Z', 'Internet of Things, Big Data, Machine Learning'),
('GTTSTM00M12L117F', 'Tecnologie digitali e comunicazione per le industrie creative'),
('RSSRCC97S04H501Y', 'Matematica'),
('FBBVKN96B14F205M', 'Artificial Intelligence & Cybersecurity'),
('LNIFNC95D22H501P', 'Artificial Intelligence & Cybersecurity'),
('SNTAND94H08L219T', 'Fisica'),
('SNTAND94H08L219T', 'Matematica'),
('GRDGNN93A01F205U', 'Matematica'),
('MLNLRA92T10F205B', 'Matematica'),
('VTTMRA91A01H501L', 'Informatica'),
('BRNAND90P15L219Q', 'Informatica'),
('BRNAND90P15L219Q', 'Tecnologie digitali e comunicazione per le industrie creative'),
('CASSRA89E20H501D', 'Tecnologie digitali e comunicazione per le industrie creative'),
('DLURST88M12L117G', 'Internet of Things, Big Data, Machine Learning'),
('ESPRCC87S04H501W', 'Matematica'),
('FRNVAL86B14F205N', 'Informatica'),
('GLLFNC85D22H501R', 'Informatica'),
('LMBAND84H08L219V', 'Fisica'),
('MRNGNN83A01F205Z', 'Fisica'),
('NRELCA82T10F205C', 'Artificial Intelligence & Cybersecurity'),
('PLTMRA81A01H501M', 'Informatica');
COMMIT;

INSERT INTO Lezione (corso, corso_di_laurea, giorno, fascia_oraria, aula, edificio) VALUES 
('Basi di Dati', 'Informatica', '2026-04-13', 'prima', 'C1', 'Rizzi'),
('Basi di Dati', 'Informatica', '2026-02-13', 'prima', 'C2', 'Rizzi'),
('Basi di Dati', 'Informatica', '2026-03-13', 'prima', 'C3', 'Rizzi'),
('Analisi', 'Informatica', '2026-04-13', 'seconda', 'C2', 'Rizzi'),
('Matematica e Statistica', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-04-14', 'terza', 'Aula Big', 'Edificio Le Aquile'),
('Sociologia della comunicazione', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-03-8', 'terza', 'Aula Big', 'Edificio Le Aquile'),
('Informatica per l''Industria Creativa', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-03-8', 'prima', 'Aula Big', 'Edificio Le Aquile'),
('Informatica per l''Industria Creativa', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-03-18', 'seconda', 'Aula Magna', 'Edificio Le Aquile'),
('Sociologia della comunicazione', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-03-9', 'seconda', 'Aula Magna', 'Edificio Le Aquile'),
('Sociologia della comunicazione', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-03-10', 'terza', 'Aula Small', 'Edificio Le Aquile'),
('Matematica e Statistica', 'Tecnologie digitali e comunicazione per le industrie creative', '2026-04-10', 'prima', 'Aula Magna', 'Edificio Le Aquile'),
('Dinamica', 'Fisica', '2026-04-14', 'quarta', 'Aula 1', 'Edificio A'),
('Advanced topics in AI I', 'Artificial Intelligence & Cybersecurity', '2026-04-15', 'prima', 'E-20', 'Edificio Conte'),
('Geometria', 'Matematica', '2026-04-15', 'seconda', 'Sala 1', 'Villa Mirafiori'),
('Calcolo Scientifico', 'Informatica', '2026-04-16', 'quarta', 'C1', 'Rizzi'),
('Basi di Dati', 'Internet of Things, Big Data, Machine Learning', '2026-04-17', 'prima', 'Aula 1', 'Edificio Torre'),
('Logica', 'Matematica', '2026-04-17', 'seconda', 'Sala 5', 'Villa Mirafiori');


-- queries

-- Operazione 4: Individuare i docenti che insegnano in almeno due corsi appartenenti ai corsi di laurea il cui responsabile e' uno specifico docente

SELECT C.docente
FROM Corso C JOIN Corso_di_Laurea CL ON C.corso_di_laurea = CL.nome JOIN Docente Resp ON CL.responsabile = Resp.cf
WHERE Resp.nome ~* 'Carla' AND Resp.cognome ~* 'Piazza'
GROUP BY C.docente
HAVING COUNT(DISTINCT C.nome) >= 2;

-- alternativa

SELECT DISTINCT d.cf
FROM Docente AS d
JOIN Corso c1 ON d.cf = c1.docente
JOIN Corso c2 ON d.cf = c2.docente
JOIN Corso_di_Laurea l1 ON l1.nome = c1.corso_di_laurea
JOIN Corso_di_Laurea l2 ON l2.nome = c2.corso_di_laurea
WHERE l1.responsabile = 'PZZCRL99P15L219X'
  AND l2.responsabile = 'PZZCRL99P15L219X'
  AND c1.nome != c2.nome;


-- Operazione 5: Trovare il corso le cui lezioni si svolgono nel maggior numero di aule distinte

WITH ConteggioAule AS (
    SELECT corso, corso_di_laurea, COUNT(DISTINCT (aula, edificio)) AS num_aule
    FROM Lezione
    GROUP BY corso, corso_di_laurea
)

SELECT C1.corso, C1.corso_di_laurea
FROM ConteggioAule C1
WHERE NOT EXISTS (
    SELECT *
    FROM ConteggioAule
    WHERE num_aule > C1.num_aule
);


-- Operazione 6: Individuare i corsi le cui lezioni si svolgono in tutte le aule utilizzate da un dato corso

SELECT nome, corso_di_laurea
FROM Corso
WHERE NOT EXISTS (
  SELECT *
  FROM Lezione L
  WHERE corso ~* 'Statistica' AND corso_di_laurea ~* 'Tecnologie digitali e comunicazione per le industrie creative' AND NOT EXISTS (
    SELECT *
    FROM Lezione
    WHERE corso = Corso.nome AND corso_di_laurea = Corso.corso_di_laurea AND aula = L.aula AND edificio = L.edificio
  )
);


-- Operazione 7: Trovare tutti gli studenti che partecipano alle lezioni tenute da uno specifico docente

SELECT DISTINCT studente
FROM Iscritto
WHERE corso_di_laurea IN (
  SELECT C.corso_di_laurea
  FROM Docente D JOIN Corso C ON D.cf = C.docente
  WHERE D.nome ~* 'Carla' AND D.cognome ~* 'Piazza'
);


-- Operazione 8: Individuare le coppie di corsi le cui lezioni si svolgono nelle stesse aule

SELECT DISTINCT C1.corso, C1.corso_di_laurea, C2.corso, C2.corso_di_laurea
FROM Lezione C1, Lezione C2
WHERE (C1.corso < C2.corso OR (C1.corso = C2.corso AND C1.corso_di_laurea < C2.corso_di_laurea)) AND
  NOT EXISTS (
  SELECT aula, edificio
  FROM Lezione
  WHERE corso = C1.corso AND corso_di_laurea = C1.corso_di_laurea
  EXCEPT
  SELECT aula, edificio
  FROM Lezione
  WHERE corso = C2.corso AND corso_di_laurea = C2.corso_di_laurea
) AND NOT EXISTS (
  SELECT aula, edificio
  FROM Lezione
  WHERE corso = C2.corso AND corso_di_laurea = C2.corso_di_laurea
  EXCEPT
  SELECT aula, edificio
  FROM Lezione
  WHERE corso = C1.corso AND corso_di_laurea = C1.corso_di_laurea
);


-- Operazione 9: Inserimento di un nuovo edificio

START TRANSACTION;
INSERT INTO Edificio VALUES ('Biblioteca A', 'Via Claudio 21, 80125', '+390817681111', NULL);
INSERT INTO Aula VALUES ('Aula A1', 'Biblioteca A', 0, 150);
COMMIT;


-- Operazione 10: Inserimento di un nuovo corso di laurea
START TRANSACTION;
INSERT INTO Corso_di_Laurea VALUES ('Ingegneria Elettronica', 0, 'GLIAND88S04L219R'); 
INSERT INTO Corso VALUES ('Analisi', 'Ingegneria Elettronica', 'GLIAND88S04L219R');
COMMIT;


-- Operazione 11: Cancellazione di un’aula appartenente a un edificio specifico

START TRANSACTION;
DELETE FROM Lezione WHERE aula = 'Aula A1' AND edificio = 'Biblioteca A';
DELETE FROM Aula WHERE nome = 'Aula A1' AND edificio = 'Biblioteca A';
COMMIT;


-- Operazione 12: Riassegnazione dell’aula associata a una specifica lezione

UPDATE Lezione
SET aula = 'Aula Magna', edificio = 'Edificio A'
WHERE corso = 'Basi di Dati' 
AND corso_di_laurea = 'Ingegneria Informatica' 
AND giorno = '2024-05-20' 
AND fascia_oraria = 'prima';













