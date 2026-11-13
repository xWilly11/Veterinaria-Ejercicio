-- VETERINARIA ADSO | MIGRACION 01 | MySQL 8.4 / InnoDB
-- Implementar DESPUES de 01_modelado_catalogo_lotes_y_seguridad.sql
--                   y 02_facturacion_inventario_y_auditoria.sql.
-- Idempotente respecto de los triggers propios: reemplaza los dos originales
-- que solo validaban fecha obligatoria y agrega control al producto.
-- NO borra datos historicos ni recrea las tablas.
USE veterinaria_adso;

DROP TRIGGER IF EXISTS trg_lote_vencimiento_bi;
DROP TRIGGER IF EXISTS trg_lote_vencimiento_bu;
DROP TRIGGER IF EXISTS trg_producto_requiere_vencimiento_bu;

DELIMITER $$

-- 1. Registrar lotes: validar producto, obligatoriedad y coherencia temporal.
CREATE TRIGGER trg_lote_vencimiento_bi
BEFORE INSERT ON lotes
FOR EACH ROW
BEGIN
    DECLARE v_requiere_vencimiento TINYINT DEFAULT NULL;

    SELECT MAX(requiere_vencimiento)
      INTO v_requiere_vencimiento
      FROM productos
     WHERE id_producto = NEW.id_producto;

    IF v_requiere_vencimiento IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'No existe el producto asociado al lote';
    END IF;

    IF NEW.fecha_ingreso > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'La fecha de ingreso del lote no puede ser futura';
    END IF;

    IF v_requiere_vencimiento = 1 AND NEW.fecha_vencimiento IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'El producto requiere fecha de vencimiento por lote';
    END IF;

    IF NEW.fecha_vencimiento IS NOT NULL THEN
        IF NEW.fecha_vencimiento < NEW.fecha_ingreso THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'No se pueden ingresar productos vencidos: fecha anterior al ingreso';
        END IF;

        IF NEW.fecha_vencimiento < CURDATE() THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'No se pueden ingresar productos vencidos: fecha anterior a hoy';
        END IF;
    END IF;
END$$

-- 2. Modificar lotes: validar SOLO cuando cambia el dato que define su
--    vencimiento, la fecha de ingreso o el producto asociado.
--    Un lote que vencio dentro de la veterinaria SI puede recibir un ajuste
--    administrativo de cantidad; el procedimiento de venta sigue impidiendo
--    la comercializacion de un lote vencido.
CREATE TRIGGER trg_lote_vencimiento_bu
BEFORE UPDATE ON lotes
FOR EACH ROW
BEGIN
    DECLARE v_requiere_vencimiento TINYINT DEFAULT NULL;

    IF NOT (NEW.id_producto <=> OLD.id_producto)
       OR NOT (NEW.fecha_ingreso <=> OLD.fecha_ingreso)
       OR NOT (NEW.fecha_vencimiento <=> OLD.fecha_vencimiento) THEN

        SELECT MAX(requiere_vencimiento)
          INTO v_requiere_vencimiento
          FROM productos
         WHERE id_producto = NEW.id_producto;

        IF v_requiere_vencimiento IS NULL THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'No existe el producto asociado al lote';
        END IF;

        IF NEW.fecha_ingreso > CURDATE() THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'La fecha de ingreso del lote no puede ser futura';
        END IF;

        IF v_requiere_vencimiento = 1 AND NEW.fecha_vencimiento IS NULL THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT = 'El producto requiere fecha de vencimiento por lote';
        END IF;

        IF NEW.fecha_vencimiento IS NOT NULL THEN
            IF NEW.fecha_vencimiento < NEW.fecha_ingreso THEN
                SIGNAL SQLSTATE '45000'
                  SET MESSAGE_TEXT = 'No se pueden ingresar productos vencidos: fecha anterior al ingreso';
            END IF;

            IF NEW.fecha_vencimiento < CURDATE() THEN
                SIGNAL SQLSTATE '45000'
                  SET MESSAGE_TEXT = 'No se pueden ingresar productos vencidos: fecha anterior a hoy';
            END IF;
        END IF;
    END IF;
END$$

-- 3. Proteccion adicional del catalogo: no cambiar un producto que tenia
--    vencimiento opcional a obligatorio si hay lotes sin esa informacion.
CREATE TRIGGER trg_producto_requiere_vencimiento_bu
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.requiere_vencimiento = 1
       AND OLD.requiere_vencimiento = 0
       AND EXISTS (
           SELECT 1
             FROM lotes
            WHERE id_producto = OLD.id_producto
              AND fecha_vencimiento IS NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Existen lotes sin vencimiento: complete sus fechas primero';
    END IF;
END$$

DELIMITER ;

-- Comprobacion: tres triggers nuevos (dos de lote y uno de producto).
SHOW TRIGGERS FROM veterinaria_adso;
