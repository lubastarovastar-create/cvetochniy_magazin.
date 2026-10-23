CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    price REAL NOT NULL,
    quantity INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL
);


CREATE TRIGGER IF NOT EXISTS trg_decrease_stock
AFTER INSERT ON order_items
BEGIN
    UPDATE products SET quantity = quantity - NEW.quantity WHERE id = NEW.product_id;
END;


CREATE TRIGGER IF NOT EXISTS trg_restore_stock
AFTER DELETE ON order_items
BEGIN
    UPDATE products SET quantity = quantity + OLD.quantity WHERE id = OLD.product_id;
END;
