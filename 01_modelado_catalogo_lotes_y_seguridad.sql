-- TALLER VETERINARIA ADSO · SESIÓN 1 / 5 HORAS
-- ADVERTENCIA: este script crea una base NUEVA y reinicia el esquema de práctica.
-- EJECUTAR UNA SOLA VEZ EN UN ENTORNO DE APRENDIZAJE.
CREATE DATABASE IF NOT EXISTS veterinaria_adso
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE veterinaria_adso;

CREATE TABLE especies (
  id_especie INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE razas (
  id_raza INT AUTO_INCREMENT PRIMARY KEY,
  id_especie INT NOT NULL,
  nombre VARCHAR(80) NOT NULL,
  UNIQUE KEY uq_raza_por_especie (id_especie, nombre),
  UNIQUE KEY uq_raza_especie (id_raza, id_especie),
  CONSTRAINT fk_raza_especie FOREIGN KEY (id_especie) REFERENCES especies(id_especie)
) ENGINE=InnoDB;

-- Un cliente puede comprar productos y, si tiene mascotas, ser su propietario.
CREATE TABLE clientes (
  id_cliente INT AUTO_INCREMENT PRIMARY KEY,
  tipo_documento VARCHAR(5) NOT NULL,
  numero_documento VARCHAR(20) NOT NULL UNIQUE,
  nombre VARCHAR(120) NOT NULL,
  telefono VARCHAR(25),
  correo VARCHAR(120),
  direccion VARCHAR(180)
) ENGINE=InnoDB;

CREATE TABLE mascotas (
  id_mascota INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT NOT NULL,
  id_especie INT NOT NULL,
  id_raza INT NOT NULL,
  nombre VARCHAR(90) NOT NULL,
  sexo ENUM('M','H','NO_DETERMINADO') NOT NULL,
  fecha_nacimiento DATE,
  identificacion VARCHAR(50) UNIQUE,
  observaciones TEXT,
  CONSTRAINT fk_mascota_propietario FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
  CONSTRAINT fk_mascota_raza_especie FOREIGN KEY (id_raza,id_especie)
    REFERENCES razas(id_raza,id_especie),
  CONSTRAINT fk_mascota_especie FOREIGN KEY (id_especie) REFERENCES especies(id_especie)
) ENGINE=InnoDB;

CREATE TABLE categorias (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(65) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE marcas (
  id_marca INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(70) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE productos (
  id_producto INT AUTO_INCREMENT PRIMARY KEY,
  id_categoria INT NOT NULL,
  id_marca INT NOT NULL,
  sku VARCHAR(30) NOT NULL UNIQUE,
  nombre VARCHAR(120) NOT NULL,
  descripcion VARCHAR(300),
  precio_venta DECIMAL(12,2) NOT NULL,
  stock_minimo INT NOT NULL DEFAULT 0,
  requiere_vencimiento BOOLEAN NOT NULL DEFAULT FALSE,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_producto_precio CHECK (precio_venta > 0),
  CONSTRAINT chk_producto_minimo CHECK (stock_minimo >= 0),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
  CONSTRAINT fk_producto_marca FOREIGN KEY (id_marca) REFERENCES marcas(id_marca)
) ENGINE=InnoDB;

-- Lote separado: un mismo SKU puede tener existencias con vencimientos distintos.
CREATE TABLE lotes (
  id_lote BIGINT AUTO_INCREMENT PRIMARY KEY,
  id_producto INT NOT NULL,
  codigo_lote VARCHAR(50) NOT NULL,
  fecha_ingreso DATE NOT NULL DEFAULT (CURRENT_DATE),
  fecha_vencimiento DATE NULL,
  cantidad_inicial INT NOT NULL,
  stock_actual INT NOT NULL,
  UNIQUE KEY uq_producto_lote (id_producto, codigo_lote),
  KEY idx_lote_fefo (id_producto, fecha_vencimiento),
  CONSTRAINT chk_lote_cantidad CHECK (cantidad_inicial >= 0),
  CONSTRAINT chk_lote_stock CHECK (stock_actual >= 0 AND stock_actual <= cantidad_inicial),
  CONSTRAINT fk_lote_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

INSERT INTO especies (nombre) VALUES ('Perro'),('Gato');
INSERT INTO razas (id_especie,nombre) VALUES
  (1,'Mestizo canino'),(1,'Labrador'),(2,'Mestizo felino'),(2,'Siamés');
INSERT INTO clientes(tipo_documento,numero_documento,nombre,telefono,correo,direccion) VALUES
  ('CC','100010001','Diana Quintero','3105550101','diana@ejemplo.test','Carrera 8 # 12-20'),
  ('CC','100010002','Camilo Torres','3105550102','camilo@ejemplo.test','Calle 15 # 10-05'),
  ('CC','100010003','Valeria Díaz','3105550103','valeria@ejemplo.test','Calle 20 # 09-40');
INSERT INTO mascotas (id_cliente,id_especie,id_raza,nombre,sexo,fecha_nacimiento,identificacion) VALUES
  (1,1,1,'Luna','H','2022-04-15','PET-001'),
  (2,2,4,'Milo','M','2023-09-10','PET-002'),
  (3,1,2,'Toby','M','2021-12-01','PET-003');
INSERT INTO categorias(nombre) VALUES
  ('Alimento seco'),('Alimento enlatado'),('Premios'),('Juguetes'),('Correas'),('Medicamentos'),('Vacunas');
INSERT INTO marcas(nombre) VALUES ('NutriCan'),('PetFun'),('VetCare'),('FelinPlus');
INSERT INTO productos(id_categoria,id_marca,sku,nombre,descripcion,precio_venta,stock_minimo,requiere_vencimiento) VALUES
  (1,1,'AL-SECO-01','Alimento seco adulto','Bolsa de alimento balanceado',79000,6,TRUE),
  (2,4,'AL-LATA-01','Alimento enlatado felino','Lata 400 g',11000,4,TRUE),
  (3,1,'PREMIO-01','Premios de entrenamiento','Paquete por unidad',18000,5,TRUE),
  (4,2,'JUG-01','Pelota de goma','Juguete para mascota',14000,4,FALSE),
  (5,2,'CORREA-01','Correa ajustable','Correa para paseo',25000,4,FALSE),
  (6,3,'MED-01','Antiparasitario veterinario','Producto de uso veterinario; no prescribe dosis',43000,5,TRUE),
  (7,3,'VAC-01','Vacuna veterinaria de inventario','Producto biológico; manejo profesional',68000,2,TRUE),
  (6,3,'MED-02','Suplemento veterinario','Presentación comercial',32000,3,TRUE);
-- Precios y nombres son ficticios. Los medicamentos/vacunas son solo productos de ejemplo.
-- Las fechas son relativas a la fecha de ejecución: ilustran próximos vencimientos y vencidos.
INSERT INTO lotes (id_producto,codigo_lote,fecha_vencimiento,cantidad_inicial,stock_actual) VALUES
  (1,'ALI-001',DATE_ADD(CURDATE(),INTERVAL 120 DAY),12,12),
  (2,'LAT-001',DATE_ADD(CURDATE(),INTERVAL 80 DAY),8,8),
  (3,'PRE-001',DATE_ADD(CURDATE(),INTERVAL 70 DAY),2,2),
  (4,'JUG-001',NULL,10,10),
  (5,'COR-001',NULL,2,2),
  (6,'MED-LOTE-A',DATE_ADD(CURDATE(),INTERVAL 45 DAY),5,5),
  (6,'MED-LOTE-B',DATE_ADD(CURDATE(),INTERVAL 170 DAY),9,9),
  (6,'MED-VENCIDO',DATE_SUB(CURDATE(),INTERVAL 5 DAY),3,3),
  (7,'VAC-001',DATE_ADD(CURDATE(),INTERVAL 160 DAY),4,4),
  (8,'SUP-001',DATE_ADD(CURDATE(),INTERVAL 90 DAY),6,6);

-- Consulta comparativa: dos lotes vigentes y uno vencido del mismo medicamento.
SELECT p.sku,p.nombre,l.codigo_lote,l.fecha_vencimiento,l.stock_actual
FROM productos p JOIN lotes l ON l.id_producto=p.id_producto
WHERE p.sku='MED-01' ORDER BY l.fecha_vencimiento;

-- Verificación del modelo.
SELECT table_name FROM information_schema.tables
WHERE table_schema='veterinaria_adso' ORDER BY table_name;


-- AMPLIACIÓN V2: SEGURIDAD DE LA APLICACIÓN (NO CONFUNDIR CON CUENTAS MySQL).
-- Passwords: jamás texto plano. El backend Java generará password_hash con PasswordEncoder.
CREATE TABLE roles (
  id_rol TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(40) NOT NULL UNIQUE,
  descripcion VARCHAR(180) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE usuarios (
  id_usuario BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre_completo VARCHAR(120) NOT NULL,
  correo VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  estado ENUM('ACTIVO','BLOQUEADO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ultimo_acceso DATETIME NULL
) ENGINE=InnoDB;

CREATE TABLE usuario_roles (
  id_usuario BIGINT UNSIGNED NOT NULL,
  id_rol TINYINT UNSIGNED NOT NULL,
  asignado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario, id_rol),
  CONSTRAINT fk_usuario_rol_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
  CONSTRAINT fk_usuario_rol_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
) ENGINE=InnoDB;

CREATE TABLE auditoria_eventos (
  id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
  id_usuario BIGINT UNSIGNED NULL,
  entidad VARCHAR(65) NOT NULL,
  id_registro VARCHAR(65) NOT NULL,
  accion ENUM('CREAR','MODIFICAR','ANULAR','CONFIRMAR','ACCESO') NOT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resumen VARCHAR(250) NOT NULL,
  CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB;

INSERT INTO roles(codigo,descripcion) VALUES
('ADMIN','Administra usuarios, perfiles y parametrización'),
('INVENTARIO','Gestiona catálogo, lotes y alertas de existencias'),
('CAJA','Registra y confirma ventas y facturas'),
('VETERINARIO','Registra atenciones, vacunas y controles'),
('RECEPCION','Registra propietarios, mascotas y agenda');

-- NO SE INSERTAN usuarios con claves inventadas. El backend del siguiente bloque de talleres
-- realizará el alta de usuarios con hashes seguros (Argon2id o BCrypt).
SELECT codigo, descripcion FROM roles ORDER BY codigo;
