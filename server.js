const express = require('express');
const cors = require('cors');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// MySQL Connection Pool
const db = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'procurement_db',
    waitForConnections: true,
    connectionLimit: 10
});

// 1. GET ALL ORDERS WITH SQL JOINS & FILTERS
app.get('/api/orders', async (req, res) => {
    try {
        const { category, status } = req.query;
        let sql = `
            SELECT 
                o.order_id,
                s.supplier_name,
                p.product_name,
                p.category,
                p.brand,
                o.demand_qty,
                o.ordered_qty,
                o.supplied_qty,
                o.remaining_qty,
                o.order_status,
                o.created_at
            FROM orders o
            INNER JOIN suppliers s ON o.supplier_id = s.supplier_id
            INNER JOIN products p ON o.product_id = p.product_id
            WHERE 1=1
        `;
        const params = [];

        if (category && category !== 'All') {
            sql += ` AND p.category = ?`;
            params.push(category);
        }
        if (status && status !== 'All') {
            sql += ` AND o.order_status = ?`;
            params.push(status);
        }

        sql += ` ORDER BY o.order_id DESC`;

        const [rows] = await db.query(sql, params);
        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// 2. ADD PRODUCT, SUPPLIER & ORDER IN SQL WORKBENCH
app.post('/api/orders', async (req, res) => {
    const { supplier_name, product_name, category, brand, demand_qty, ordered_qty } = req.body;
    
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();

        // Step A: Insert or Get Supplier ID
        let [supplierResult] = await connection.query('SELECT supplier_id FROM suppliers WHERE supplier_name = ?', [supplier_name]);
        let supplier_id;
        if (supplierResult.length > 0) {
            supplier_id = supplierResult[0].supplier_id;
        } else {
            const [newSupplier] = await connection.query('INSERT INTO suppliers (supplier_name) VALUES (?)', [supplier_name]);
            supplier_id = newSupplier.insertId;
        }

        // Step B: Insert Product
        const [newProduct] = await connection.query(
            'INSERT INTO products (product_name, category, brand) VALUES (?, ?, ?)',
            [product_name, category, brand]
        );
        const product_id = newProduct.insertId;

        // Step C: Insert Order (Trigger will handle order_status automatically)
        await connection.query(
            'INSERT INTO orders (supplier_id, product_id, demand_qty, ordered_qty, supplied_qty) VALUES (?, ?, ?, ?, 0)',
            [supplier_id, product_id, demand_qty, ordered_qty]
        );

        await connection.commit();
        res.json({ success: true, message: 'Order, Product & Supplier linked successfully!' });
    } catch (error) {
        await connection.rollback();
        res.status(500).json({ success: false, message: error.message });
    } finally {
        connection.release();
    }
});

// 3. UPDATE SUPPLIED QTY (SQL Trigger automatically updates status)
app.put('/api/orders/:id/supply', async (req, res) => {
    const { id } = req.params;
    const { add_supplied } = req.body;

    try {
        const [rows] = await db.query('SELECT supplied_qty FROM orders WHERE order_id = ?', [id]);
        if (rows.length === 0) return res.status(404).json({ success: false, message: 'Order not found' });

        const newSupplied = rows[0].supplied_qty + parseInt(add_supplied);

        // Trigger updates order_status automatically on table UPDATE
        await db.query('UPDATE orders SET supplied_qty = ? WHERE order_id = ?', [newSupplied, id]);

        res.json({ success: true, message: 'Delivery quantity updated!' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// 4. DELETE ORDER
app.delete('/api/orders/:id', async (req, res) => {
    try {
        await db.query('DELETE FROM orders WHERE order_id = ?', [req.params.id]);
        res.json({ success: true, message: 'Order deleted from Database!' });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
    console.log(`🚀 Procurement Dashboard Server running on http://localhost:${PORT}`);
});