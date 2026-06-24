-- queries

-- Operazione 4: Individuare i docenti che insegnano in almeno due corsi appartenenti ai corsi di laurea il cui responsabile e' uno specifico docente

SELECT DISTINCT D.cf, D.nome, D.cognome
FROM Corso c1
JOIN Corso c2 ON c1.docente = c2.docente
JOIN Corso_di_Laurea l1 ON l1.nome = c1.corso_di_laurea
JOIN Corso_di_Laurea l2 ON l2.nome = c2.corso_di_laurea
JOIN Docente Resp1 ON l1.responsabile = Resp1.cf
JOIN Docente Resp2 ON l2.responsabile = Resp2.cf
JOIN Docente D ON c1.docente = D.cf
WHERE Resp1.nome ~* 'Carla' AND Resp1.cognome ~* 'Piazza'
  AND Resp2.nome ~* 'Carla' AND Resp2.cognome ~* 'Piazza'
  AND c1.nome != c2.nome;


-- Operazione 5: Trovare il corso le cui lezioni si svolgono nel maggior numero di aule distinte

SELECT DISTINCT L1.corso, L1.corso_di_laurea
FROM Lezione L1
WHERE NOT EXISTS (
  SELECT *
  FROM Lezione L2
  WHERE (
    SELECT COUNT(DISTINCT (aula, edificio))
    FROM Lezione
    WHERE corso = L2.corso AND corso_di_laurea = L2.corso_di_laurea
  ) > (
    SELECT COUNT(DISTINCT (aula, edificio))
    FROM Lezione
    WHERE corso = L1.corso AND corso_di_laurea = L1.corso_di_laurea
  )
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

SELECT DISTINCT S.nome, S.cognome
FROM Studente S
JOIN Iscritto I ON S.cf = I.studente
WHERE EXISTS (
  SELECT *
  FROM Docente D 
  JOIN Corso C ON D.cf = C.docente
  WHERE D.nome ~* 'Carla' AND D.cognome ~* 'Piazza' 
    AND C.corso_di_laurea = I.corso_di_laurea
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