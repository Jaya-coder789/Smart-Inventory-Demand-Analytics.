-- ============================================================
-- APEX TECH SOLUTIONS - ENTERPRISE PROCUREMENT SYSTEM SCHEMA
-- Includes: Tables, Foreign Keys, Joins, Triggers, Procedures & Filters
-- ============================================================

CREATE DATABASE IF NOT EXISTS procurement_db;
USE procurement_db;

-- ------------------------------------------------------------
-- 1. CLEANUP OLD TABLES IF THEY EXIST
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_update_order_status_before_insert;
DROP TRIGGER IF EXISTS trg_update_order_status_before_update;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS suppliers;

-- ------------------------------------------------------------
-- 2. CREATE TABLES (Relational Model)
-- ------------------------------------------------------------

-- A. Suppliers Table
CREATE TABLE suppliers (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL UNIQUE,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- B. Products Table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- C. Orders Table (With Foreign Keys & Auto-Generated Column)
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    product_id INT NOT NULL,
    demand_qty INT NOT NULL CHECK (demand_qty > 0),
    ordered_qty INT NOT NULL CHECK (ordered_qty > 0),
    supplied_qty INT DEFAULT 0 CHECK (supplied_qty >= 0),
    remaining_qty INT GENERATED ALWAYS AS (ordered_qty - supplied_qty) STORED,
    order_status VARCHAR(20) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 3. AUTOMATED TRIGGERS FOR ORDER STATUS
-- ------------------------------------------------------------

DELIMITER //

-- Trigger 1: Insert ke wqt status decide karega
CREATE TRIGGER trg_update_order_status_before_insert
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    IF NEW.supplied_qty >= NEW.ordered_qty THEN
        SET NEW.order_status = 'Fulfilled';
    ELSEIF NEW.supplied_qty > 0 THEN
        SET NEW.order_status = 'Partial';
    ELSE
        SET NEW.order_status = 'Pending';
    END IF;
END//

-- Trigger 2: Delivery update ke wqt status automatic change karega
CREATE TRIGGER trg_update_order_status_before_update
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.supplied_qty >= NEW.ordered_qty THEN
        SET NEW.order_status = 'Fulfilled';
    ELSEIF NEW.supplied_qty > 0 THEN
        SET NEW.order_status = 'Partial';
    ELSE
        SET NEW.order_status = 'Pending';
    END IF;
END//

DELIMITER ;

-- ------------------------------------------------------------
-- 4. INSERT INITIAL DUMMY DATA
-- ------------------------------------------------------------

-- Insert Suppliers
INSERT INTO suppliers (supplier_name, contact_person, email, phone) VALUES
('TechData Logistics', 'Rajesh Sharma', 'rajesh@techdata.com', '9876543210'),
('Global Components', 'Priya Verma', 'priya@globalcomp.com', '9812345678'),
('Micro Devices Inc', 'Amit Patel', 'amit@microdevices.com', '9988776655');

-- Insert Products
INSERT INTO products (product_name, category, brand) VALUES
('XPS 15 Laptop', 'Laptops', 'Dell'),
('Core i9 Processor', 'Processors', 'Intel'),
('UltraSharp 27" Monitor', 'Monitors', 'Dell'),
('980 PRO 1TB NVMe SSD', 'Storage & SSDs', 'Samsung');

-- Insert Orders
INSERT INTO orders (supplier_id, product_id, demand_qty, ordered_qty, supplied_qty) VALUES
(1, 1, 120, 100, 80),  -- Status will be 'Partial' (by Trigger)
(2, 2, 300, 300, 300), -- Status will be 'Fulfilled' (by Trigger)
(3, 3, 75, 50, 0);     -- Status will be 'Pending' (by Trigger)