USE FlowerShopDB;
GO
CREATE SCHEMA shop;
GO

  
CREATE TABLE shop.products (
    id        INT IDENTITY(1,1) PRIMARY KEY,
    name      NVARCHAR(100) NOT NULL UNIQUE,
    category  NVARCHAR(50) NOT NULL CHECK (category IN (N'Цветы', N'Букеты', N'Аксессуары')),
    price     DECIMAL(10,2) NOT NULL CHECK (price > 0),
    quantity  INT NOT NULL DEFAULT 0 CHECK (quantity >= 0)
);

CREATE TABLE shop.customers (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    full_name  NVARCHAR(150) NOT NULL,
    phone      NVARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE shop.orders (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT NOT NULL,
    created_at   DATETIME2 DEFAULT SYSDATETIME(),
    FOREIGN KEY (customer_id) REFERENCES shop.customers(id) ON DELETE CASCADE
);

CREATE TABLE shop.order_items (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    order_id    INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT NOT NULL CHECK (quantity > 0),
    price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
    FOREIGN KEY (order_id) REFERENCES shop.orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES shop.products(id)
);
GO


INSERT INTO shop.products (name, category, price, quantity) VALUES 
(N'Роза красная', N'Цветы', 250.00, 100), (N'Букет «Весенний»', N'Букеты', 1500.00, 20);
INSERT INTO shop.customers (full_name, phone) VALUES 
(N'Иванова Анна', N'+7-900-111-22-33'), (N'Петров Сергей', N'+7-900-444-55-66');
GO
  
CREATE INDEX ix_products_name ON shop.products(name);
CREATE INDEX ix_orders_created_at ON shop.orders(created_at);
GO

CREATE VIEW shop.v_daily_revenue AS
SELECT CAST(o.created_at AS DATE) AS sale_date, COUNT(DISTINCT o.id) AS orders_count, SUM(oi.quantity * oi.price) AS revenue
FROM shop.orders o JOIN shop.order_items oi ON oi.order_id = o.id
GROUP BY CAST(o.created_at AS DATE);
GO

  
CREATE PROCEDURE shop.proc_Products_GetAll AS
BEGIN SELECT * FROM shop.products ORDER BY name; END
GO

CREATE PROCEDURE shop.proc_Orders_Create @CustomerId INT, @OrderId INT OUTPUT AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM shop.customers WHERE id = @CustomerId) THROW 50010, N'Клиент не найден', 1;
    INSERT INTO shop.orders (customer_id) VALUES (@CustomerId);
    SET @OrderId = SCOPE_IDENTITY();
END
GO

  
CREATE FUNCTION shop.fn_OrderItem_LineTotal (@Quantity INT, @Price DECIMAL(10,2))
RETURNS DECIMAL(10,2) AS
BEGIN
    IF @Quantity IS NULL OR @Price IS NULL OR @Quantity <= 0 RETURN 0;
    RETURN @Quantity * @Price;
END
GO

CREATE FUNCTION shop.fn_Orders_ByCustomer (@CustomerId INT)
RETURNS TABLE AS
RETURN (SELECT id, created_at, (SELECT SUM(quantity * price) FROM shop.order_items WHERE order_id = o.id) AS total
        FROM shop.orders o WHERE customer_id = @CustomerId)
GO

CREATE TABLE shop.audit_log (
    id INT IDENTITY(1,1) PRIMARY KEY, table_name NVARCHAR(100), operation NVARCHAR(10),
    old_value NVARCHAR(MAX), new_value NVARCHAR(MAX), changed_at DATETIME2 DEFAULT GETDATE()
);
GO

  
CREATE TRIGGER shop.trg_Products_Audit_Update ON shop.products AFTER UPDATE AS
BEGIN
    INSERT INTO shop.audit_log (table_name, operation, old_value, new_value)
    SELECT N'products', N'UPDATE', CONCAT(N'price=', d.price), CONCAT(N'price=', i.price)
    FROM inserted i JOIN deleted d ON d.id = i.id;
END
GO

CREATE TRIGGER shop.trg_OrderItems_CheckStock ON shop.order_items AFTER INSERT AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted i JOIN shop.products p ON p.id = i.product_id WHERE i.quantity > p.quantity)
    BEGIN
        THROW 50020, N'Недостаточно товара на складе', 1;
    END
END
GO
