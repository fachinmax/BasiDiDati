-- triggers

-- vincolo integrita' 3: un docente non puo' essere anche uno studente e, viceversa, uno studente non puo' essere anche un docente

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


-- vincolo integrita' 4: ogni studente deve essere iscritto ad almeno un corso di laurea.
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
AFTER INSERT OR DELETE OR UPDATE ON Iscritto
FOR EACH ROW
EXECUTE FUNCTION update_student_count();

CREATE TRIGGER trg_enrollment_count_upd
AFTER UPDATE OF corso_di_laurea ON Iscritto
FOR EACH ROW
WHEN (OLD.corso_di_laurea IS DISTINCT FROM NEW.corso_di_laurea)
EXECUTE FUNCTION update_student_count();