-- TALLER VETERINARIA ADSO · SESIÓN 3 / 5 HORAS
-- REQUISITO: ejecutar 01_...sql y 02_...sql en ese orden.
USE veterinaria_adso;

-- Claves compuestas para evitar cruzar especies o mascotas en relaciones clinicas.
ALTER TABLE mascotas ADD UNIQUE KEY uq_mascota_especie (id_mascota,id_especie);

CREATE TABLE veterinarios (
  id_veterinario INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  tarjeta_profesional VARCHAR(45) NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

-- Una consulta es un evento clínico; se conserva historial, no se sobrescribe.
CREATE TABLE consultas_clinicas (
  id_consulta BIGINT AUTO_INCREMENT PRIMARY KEY,
  id_mascota INT NOT NULL,
  id_veterinario INT NOT NULL,
  fecha_atencion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo VARCHAR(220) NOT NULL,
  peso_kg DECIMAL(6,2) NULL,
  temperatura_c DECIMAL(4,1) NULL,
  hallazgos TEXT,
  diagnostico TEXT,
  plan_manejo TEXT,
  UNIQUE KEY uq_consulta_mascota (id_consulta,id_mascota),
  CONSTRAINT chk_peso_valido CHECK(peso_kg IS NULL OR peso_kg>0),
  CONSTRAINT fk_consulta_mascota FOREIGN KEY(id_mascota) REFERENCES mascotas(id_mascota),
  CONSTRAINT fk_consulta_veterinario FOREIGN KEY(id_veterinario) REFERENCES veterinarios(id_veterinario)
) ENGINE=InnoDB;

-- Este catálogo es parametrización local, NO calendario universal de vacunación.
CREATE TABLE vacunas_catalogo (
  id_vacuna INT AUTO_INCREMENT PRIMARY KEY,
  id_especie INT NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  descripcion VARCHAR(250),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_vacuna_especie (id_especie,nombre),
  UNIQUE KEY uq_vacuna_id_especie (id_vacuna,id_especie),
  CONSTRAINT fk_vacuna_especie FOREIGN KEY(id_especie) REFERENCES especies(id_especie)
) ENGINE=InnoDB;

CREATE TABLE vacunaciones (
  id_vacunacion BIGINT AUTO_INCREMENT PRIMARY KEY,
  id_consulta BIGINT NOT NULL,
  id_mascota INT NOT NULL,
  id_vacuna INT NOT NULL,
  id_especie INT NOT NULL,
  fecha_aplicacion DATE NOT NULL,
  lote_biologico VARCHAR(55) NOT NULL,
  fecha_proxima_sugerida DATE NULL,
  observaciones TEXT,
  CONSTRAINT chk_proxima_fecha CHECK(fecha_proxima_sugerida IS NULL OR fecha_proxima_sugerida>=fecha_aplicacion),
  CONSTRAINT fk_vacunacion_consulta FOREIGN KEY(id_consulta,id_mascota)
    REFERENCES consultas_clinicas(id_consulta,id_mascota),
  CONSTRAINT fk_vacunacion_mascota FOREIGN KEY(id_mascota,id_especie)
    REFERENCES mascotas(id_mascota,id_especie),
  CONSTRAINT fk_vacunacion_catalogo FOREIGN KEY(id_vacuna,id_especie)
    REFERENCES vacunas_catalogo(id_vacuna,id_especie)
) ENGINE=InnoDB;

CREATE TABLE seguimientos (
  id_seguimiento BIGINT AUTO_INCREMENT PRIMARY KEY,
  id_mascota INT NOT NULL,
  id_especie INT NOT NULL,
  id_consulta_origen BIGINT NULL,
  id_vacuna INT NULL,
  tipo ENUM('VACUNACION','CONTROL','CONSULTA') NOT NULL,
  fecha_programada DATE NOT NULL,
  estado ENUM('PENDIENTE','REALIZADO','CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
  observacion VARCHAR(250),
  CONSTRAINT chk_seg_vacuna CHECK(tipo<>'VACUNACION' OR id_vacuna IS NOT NULL),
  CONSTRAINT fk_seguimiento_mascota FOREIGN KEY(id_mascota,id_especie) REFERENCES mascotas(id_mascota,id_especie),
  CONSTRAINT fk_seguimiento_consulta FOREIGN KEY(id_consulta_origen,id_mascota)
    REFERENCES consultas_clinicas(id_consulta,id_mascota),
  CONSTRAINT fk_seguimiento_vacuna FOREIGN KEY(id_vacuna,id_especie) REFERENCES vacunas_catalogo(id_vacuna,id_especie)
) ENGINE=InnoDB;

-- Datos completamente ficticios. El profesional determina clínicamente cada fecha.
INSERT INTO veterinarios(nombre,tarjeta_profesional) VALUES
  ('Dra. Paula Mendoza','MV-ADSO-001'),('Dr. Samuel Rojas','MV-ADSO-002');
INSERT INTO vacunas_catalogo(id_especie,nombre,descripcion) VALUES
  (1,'Vacuna canina de ejemplo','Registro didáctico; no equivale a pauta médica'),
  (2,'Vacuna felina de ejemplo','Registro didáctico; no equivale a pauta médica');
INSERT INTO consultas_clinicas (id_mascota,id_veterinario,motivo,peso_kg,temperatura_c,hallazgos,diagnostico,plan_manejo)
VALUES (1,1,'Control general de ejemplo',12.40,38.2,'Hallazgos didácticos simulados',
        'Registro demostrativo sin diagnóstico real','Control conforme a valoración profesional');

-- Registrar vacunación ficticia vinculada a esa consulta.
INSERT INTO vacunaciones(id_consulta,id_mascota,id_vacuna,id_especie,fecha_aplicacion,lote_biologico,fecha_proxima_sugerida,observaciones)
VALUES (1,1,1,1,CURDATE(),'BIO-FICT-001',DATE_ADD(CURDATE(),INTERVAL 30 DAY),
        'La fecha está definida para el ejemplo; no es recomendación clínica');
INSERT INTO seguimientos(id_mascota,id_especie,id_consulta_origen,id_vacuna,tipo,fecha_programada,observacion)
VALUES (1,1,1,1,'VACUNACION',DATE_ADD(CURDATE(),INTERVAL 30 DAY),'Verificar indicación profesional'),
       (1,1,1,NULL,'CONTROL',DATE_ADD(CURDATE(),INTERVAL 14 DAY),'Control de seguimiento ficticio'),
       (2,2,NULL,NULL,'CONTROL',DATE_ADD(CURDATE(),INTERVAL 7 DAY),'Agendamiento de ejemplo');

CREATE OR REPLACE VIEW vw_historia_clinica AS
SELECT c.id_consulta,c.fecha_atencion,m.id_mascota,m.nombre AS mascota,
       cl.nombre AS propietario,e.nombre AS especie,r.nombre AS raza,
       v.nombre AS veterinario,c.motivo,c.peso_kg,c.temperatura_c,
       c.hallazgos,c.diagnostico,c.plan_manejo
FROM consultas_clinicas c
JOIN mascotas m ON m.id_mascota=c.id_mascota
JOIN clientes cl ON cl.id_cliente=m.id_cliente
JOIN especies e ON e.id_especie=m.id_especie
JOIN razas r ON r.id_raza=m.id_raza
JOIN veterinarios v ON v.id_veterinario=c.id_veterinario;

CREATE OR REPLACE VIEW vw_agenda_proxima AS
SELECT s.id_seguimiento,m.nombre AS mascota,c.nombre AS propietario,
       s.tipo,s.fecha_programada,s.estado,s.observacion,
       DATEDIFF(s.fecha_programada,CURDATE()) AS dias_para_cita
FROM seguimientos s JOIN mascotas m ON m.id_mascota=s.id_mascota
JOIN clientes c ON c.id_cliente=m.id_cliente
WHERE s.estado='PENDIENTE'
  AND s.fecha_programada BETWEEN CURDATE() AND DATE_ADD(CURDATE(),INTERVAL 30 DAY);

SELECT * FROM vw_historia_clinica ORDER BY fecha_atencion DESC;
SELECT * FROM vw_agenda_proxima ORDER BY fecha_programada;
SELECT m.nombre AS mascota,v.fecha_aplicacion,v.lote_biologico,
       vc.nombre AS vacuna,v.fecha_proxima_sugerida
FROM vacunaciones v JOIN mascotas m ON m.id_mascota=v.id_mascota
JOIN vacunas_catalogo vc ON vc.id_vacuna=v.id_vacuna;


-- AMPLIACIÓN V2: vínculo del personal con usuario de aplicación y lote biológico.
ALTER TABLE veterinarios
 ADD COLUMN id_usuario BIGINT UNSIGNED NULL UNIQUE,
 ADD CONSTRAINT fk_veterinario_usuario FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario);
ALTER TABLE consultas_clinicas
 ADD COLUMN id_usuario_registro BIGINT UNSIGNED NULL,
 ADD CONSTRAINT fk_consulta_usuario FOREIGN KEY(id_usuario_registro) REFERENCES usuarios(id_usuario);
ALTER TABLE seguimientos
 ADD COLUMN id_usuario_programador BIGINT UNSIGNED NULL,
 ADD CONSTRAINT fk_seguimiento_usuario FOREIGN KEY(id_usuario_programador) REFERENCES usuarios(id_usuario);
ALTER TABLE vacunaciones
 ADD COLUMN id_lote BIGINT NULL,
 ADD CONSTRAINT fk_vacunacion_lote FOREIGN KEY(id_lote) REFERENCES lotes(id_lote);

-- ACLARACIÓN CLAVE PARA LA SIGUIENTE FASE JAVA:
-- Si la vacunación consume inventario de vacunas, se verificará vigencia + disponibilidad
-- y se descontará el lote y registrará su movimiento en UNA transacción.
-- Esta versión no realiza automáticamente dicho descuento; no simularlo como implementado.
SELECT c.id_consulta, m.nombre AS mascota, v.nombre AS veterinario
FROM consultas_clinicas c JOIN mascotas m ON m.id_mascota=c.id_mascota
JOIN veterinarios v ON v.id_veterinario=c.id_veterinario;
