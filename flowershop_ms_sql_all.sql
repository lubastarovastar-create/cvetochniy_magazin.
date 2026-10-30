
IF DB_ID('FlowerShopDB') IS NOT NULL
BEGIN
    ALTER DATABASE FlowerShopDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FlowerShopDB;
END
GO
CREATE DATABASE FlowerShopDB;
GO
USE FlowerShopDB;
GO
CREATE SCHEMA shop;
GO

CREATE TABLE shop.products (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    name         NVARCHAR(100) NOT NULL UNIQUE,
    category     NVARCHAR(50)  NOT NULL
                 CHECK (category IN (N'Цветы', N'Букеты', N'Композиции', N'Аксессуары')),
    price        DECIMAL(10,2) NOT NULL CHECK (price > 0),
    quantity     INT           NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    is_archived  BIT           NOT NULL DEFAULT 0
);

CREATE TABLE shop.customers (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    full_name  NVARCHAR(150) NOT NULL CHECK (LEN(full_name) >= 3),
    phone      NVARCHAR(20)  NOT NULL UNIQUE CHECK (phone LIKE N'+%')
);


CREATE TABLE shop.orders (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT NOT NULL,
    created_at   DATETIME2 DEFAULT SYSDATETIME(),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES shop.customers(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE shop.order_items (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    order_id    INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT NOT NULL CHECK (quantity > 0),
    price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES shop.orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES shop.products(id)
        ON DELETE NO ACTION ON UPDATE CASCADE
);

-
CREATE TABLE shop.audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    table_name  NVARCHAR(100) NOT NULL,
    operation   NVARCHAR(15)  NOT NULL,
    record_id   INT,
    old_value   NVARCHAR(MAX),
    new_value   NVARCHAR(MAX),
    changed_by  NVARCHAR(100) DEFAULT SYSTEM_USER,
    changed_at  DATETIME2     DEFAULT GETDATE()
);
GO

-- ---------- Индексы ----------
CREATE INDEX ix_products_name        ON shop.products(name);
CREATE INDEX ix_products_category    ON shop.products(category);
CREATE INDEX ix_orders_created_at    ON shop.orders(created_at);
CREATE INDEX ix_orders_customer      ON shop.orders(customer_id);
CREATE INDEX ix_order_items_order    ON shop.order_items(order_id);
CREATE INDEX ix_order_items_product  ON shop.order_items(product_id);
GO

-- ---------- Представления ----------
CREATE VIEW shop.v_daily_revenue AS
SELECT CAST(o.created_at AS DATE) AS sale_date,
       COUNT(DISTINCT o.id) AS orders_count,
       SUM(oi.quantity)     AS items_sold,
       SUM(oi.quantity * oi.price) AS revenue
FROM shop.orders o
JOIN shop.order_items oi ON oi.order_id = o.id
GROUP BY CAST(o.created_at AS DATE);
GO

CREATE VIEW shop.v_customer_orders AS
SELECT o.id AS order_id, c.full_name AS customer, c.phone,
       o.created_at, p.name AS product,
       oi.quantity, oi.price, oi.quantity * oi.price AS line_total
FROM shop.orders o
JOIN shop.customers c    ON c.id = o.customer_id
JOIN shop.order_items oi ON oi.order_id = o.id
JOIN shop.products p     ON p.id = oi.product_id;
GO

CREATE VIEW shop.v_product_sales AS
SELECT p.id, p.name, p.category,
       ISNULL(SUM(oi.quantity), 0) AS total_sold,
       ISNULL(SUM(oi.quantity * oi.price), 0) AS total_revenue
FROM shop.products p
LEFT JOIN shop.order_items oi ON oi.product_id = p.id
GROUP BY p.id, p.name, p.category;
GO

-- ---------- Тестовые данные ----------
INSERT INTO shop.products (name, category, price, quantity) VALUES
    (N'Роза красная',          N'Цветы',      250.00, 100),
    (N'Роза белая',            N'Цветы',      280.00,  80),
    (N'Тюльпан жёлтый',        N'Цветы',      150.00, 120),
    (N'Хризантема белая',      N'Цветы',      180.00,  70),
    (N'Букет «Весенний»',      N'Букеты',    1500.00,  20),
    (N'Букет «Романтика»',     N'Букеты',    2200.00,  15),
    (N'Композиция «Утро»',     N'Композиции', 2500.00,  10),
    (N'Открытка «С любовью»',  N'Аксессуары',  120.00,  50);

INSERT INTO shop.customers (full_name, phone) VALUES
    (N'Иванова Анна Сергеевна',    N'+7-900-111-22-33'),
    (N'Петров Сергей Иванович',    N'+7-900-444-55-66'),
    (N'Смирнова Ольга Петровна',   N'+7-900-777-88-99'),
    (N'Кузнецов Дмитрий Олегович', N'+7-900-222-33-44'),
    (N'Соколова Мария Андреевна',  N'+7-900-555-66-77');

INSERT INTO shop.orders (customer_id, created_at) VALUES
    (1, DATEADD(DAY, -10, SYSDATETIME())),
    (2, DATEADD(DAY,  -8, SYSDATETIME())),
    (3, DATEADD(DAY,  -5, SYSDATETIME())),
    (1, DATEADD(DAY,  -2, SYSDATETIME())),
    (4, SYSDATETIME());

INSERT INTO shop.order_items (order_id, product_id, quantity, price) VALUES
    (1, 1, 5,  250.00), (1, 8, 1, 120.00),
    (2, 5, 1, 1500.00),
    (3, 3, 10, 150.00), (3, 8, 2, 120.00),
    (4, 2, 3,  280.00), (4, 6, 1, 2200.00),
    (5, 7, 1, 2500.00);
GO
 
CREATE PROCEDURE shop.proc_Products_GetAll AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, category, price, quantity FROM shop.products
    WHERE is_archived = 0 ORDER BY name;
END
GO

-- ---------- 2) Выборка: товары по названию ----------
CREATE PROCEDURE shop.proc_Products_GetByName @Name NVARCHAR(100) = NULL AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, name, category, price, quantity FROM shop.products
    WHERE (@Name IS NULL OR name LIKE @Name + N'%') AND is_archived = 0
    ORDER BY name;
END
GO

-- ---------- 3) Выборка: все покупатели ----------
CREATE PROCEDURE shop.proc_Customers_GetAll AS
BEGIN
    SET NOCOUNT ON;
    SELECT id, full_name, phone FROM shop.customers ORDER BY full_name;
END
GO

-- ---------- 4) Выборка: заказы покупателя ----------
CREATE PROCEDURE shop.proc_Orders_GetByCustomer @CustomerId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.id, o.created_at, c.full_name,
           (SELECT SUM(quantity * price) FROM shop.order_items WHERE order_id = o.id) AS total
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    WHERE o.customer_id = @CustomerId
    ORDER BY o.created_at DESC;
END
GO

-- ---------- 5) Выборка: позиции заказа ----------
CREATE PROCEDURE shop.proc_OrderItems_GetByOrder @OrderId INT AS
BEGIN
    SET NOCOUNT ON;
    SELECT oi.id, p.name AS product, oi.quantity, oi.price,
           shop.fn_OrderItem_LineTotal(oi.quantity, oi.price) AS line_total
    FROM shop.order_items oi
    JOIN shop.products p ON p.id = oi.product_id
    WHERE oi.order_id = @OrderId;
END
GO

-- ---------- 6) Модификация: добавить товар ----------
CREATE PROCEDURE shop.proc_Products_Create
    @Name NVARCHAR(100), @Category NVARCHAR(50),
    @Price DECIMAL(10,2), @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Name IS NULL OR @Name = ''  THROW 50001, N'Название пустое', 1;
    IF @Price <= 0                  THROW 50002, N'Цена должна быть > 0', 1;
    IF @Quantity < 0                THROW 50003, N'Количество < 0', 1;
    INSERT INTO shop.products (name, category, price, quantity)
    VALUES (@Name, @Category, @Price, @Quantity);
END
GO

-- ---------- 7) Модификация: обновить цену ----------
CREATE PROCEDURE shop.proc_Products_UpdatePrice
    @ProductId INT, @NewPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF @NewPrice <= 0 THROW 50004, N'Цена должна быть > 0', 1;
    IF NOT EXISTS (SELECT 1 FROM shop.products WHERE id = @ProductId)
        THROW 50005, N'Товар не найден', 1;
    UPDATE shop.products SET price = @NewPrice WHERE id = @ProductId;
END
GO

-- ---------- 8) Модификация: добавить покупателя ----------
CREATE PROCEDURE shop.proc_Customers_Create
    @FullName NVARCHAR(150), @Phone NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF LEN(@FullName) < 3 THROW 50006, N'ФИО короче 3 символов', 1;
    IF @Phone NOT LIKE N'+%' THROW 50007, N'Телефон должен начинаться с +', 1;
    INSERT INTO shop.customers (full_name, phone) VALUES (@FullName, @Phone);
END
GO

-- ---------- 9) Модификация: удалить покупателя ----------
CREATE PROCEDURE shop.proc_Customers_Delete @CustomerId INT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM shop.orders WHERE customer_id = @CustomerId)
        THROW 50008, N'Нельзя удалить покупателя с заказами', 1;
    DELETE FROM shop.customers WHERE id = @CustomerId;
END
GO

-- ---------- 10) Модификация: удалить товар ----------
CREATE PROCEDURE shop.proc_Products_Delete @ProductId INT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM shop.order_items WHERE product_id = @ProductId)
        THROW 50009, N'Нельзя удалить товар из заказов', 1;
    DELETE FROM shop.products WHERE id = @ProductId;
END
GO

-- ---------- 11) OUTPUT: создать заказ ----------
CREATE PROCEDURE shop.proc_Orders_Create
    @CustomerId INT, @OrderId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM shop.customers WHERE id = @CustomerId)
        THROW 50010, N'Покупатель не найден', 1;
    INSERT INTO shop.orders (customer_id) VALUES (@CustomerId);
    SET @OrderId = SCOPE_IDENTITY();
END
GO

-- ---------- 12) OUTPUT: подсчитать заказы клиента ----------
CREATE PROCEDURE shop.proc_Customers_CountOrders
    @CustomerId INT, @OrdersCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @OrdersCount = COUNT(*) FROM shop.orders WHERE customer_id = @CustomerId;
END
GO

-- ---------- 13) Транзакция: добавить позицию с проверкой остатка ----------
CREATE PROCEDURE shop.proc_OrderItems_AddItem
    @OrderId INT, @ProductId INT, @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @Quantity <= 0 THROW 50011, N'Количество должно быть > 0', 1;
        DECLARE @Price DECIMAL(10,2), @Stock INT;
        SELECT @Price = price, @Stock = quantity
        FROM shop.products WHERE id = @ProductId;
        IF @Price IS NULL THROW 50012, N'Товар не найден', 1;
        IF @Stock < @Quantity THROW 50013, N'Недостаточно товара', 1;

        INSERT INTO shop.order_items (order_id, product_id, quantity, price)
        VALUES (@OrderId, @ProductId, @Quantity, @Price);

        UPDATE shop.products SET quantity = quantity - @Quantity
        WHERE id = @ProductId;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- ---------- 14) Транзакция: удалить заказ со всеми позициями ----------
CREATE PROCEDURE shop.proc_Orders_Delete @OrderId INT AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM shop.orders WHERE id = @OrderId)
            THROW 50014, N'Заказ не найден', 1;
        DELETE FROM shop.order_items WHERE order_id = @OrderId;
        DELETE FROM shop.orders WHERE id = @OrderId;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO

-- ---------- 15) Отчёт: дневная выручка ----------
CREATE PROCEDURE shop.proc_Report_DailyRevenue
    @DateFrom DATE, @DateTo DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM shop.v_daily_revenue
    WHERE sale_date BETWEEN @DateFrom AND @DateTo
    ORDER BY sale_date;
END
GO

CREATE PROCEDURE shop.proc_Report_TopProducts @TopN INT = 5 AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN) name AS product, category, total_sold, total_revenue
    FROM shop.v_product_sales ORDER BY total_revenue DESC;
END
GO


CREATE FUNCTION shop.fn_OrderItem_LineTotal (@Quantity INT, @Price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @Quantity IS NULL OR @Price IS NULL OR @Quantity <= 0 OR @Price <= 0
        RETURN 0;
    RETURN @Quantity * @Price;
END
GO


CREATE FUNCTION shop.fn_Order_Total (@OrderId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total DECIMAL(10,2);
    SELECT @Total = ISNULL(SUM(quantity * price), 0)
    FROM shop.order_items WHERE order_id = @OrderId;
    RETURN @Total;
END
GO


CREATE FUNCTION shop.fn_Customer_ShortName (@FullName NVARCHAR(150))
RETURNS NVARCHAR(100)
AS
BEGIN
    IF @FullName IS NULL OR LTRIM(RTRIM(@FullName)) = '' RETURN N'';
    DECLARE @T NVARCHAR(150) = LTRIM(RTRIM(@FullName));
    DECLARE @S1 INT = CHARINDEX(' ', @T);
    IF @S1 = 0 RETURN @T;
    DECLARE @Surname NVARCHAR(100) = LEFT(@T, @S1 - 1);
    DECLARE @Rest NVARCHAR(150) = LTRIM(SUBSTRING(@T, @S1 + 1, LEN(@T)));
    DECLARE @S2 INT = CHARINDEX(' ', @Rest);
    IF @S2 = 0 RETURN @Surname + N' ' + LEFT(@Rest, 1) + N'.';
    RETURN @Surname + N' ' + LEFT(@Rest, 1) + N'.' + LEFT(SUBSTRING(@Rest, @S2 + 1, LEN(@Rest)), 1) + N'.';
END
GO


CREATE FUNCTION shop.fn_Order_AgeDays (@CreatedAt DATETIME2)
RETURNS INT
AS
BEGIN
    IF @CreatedAt IS NULL RETURN NULL;
    IF @CreatedAt > SYSDATETIME() RETURN 0;
    RETURN DATEDIFF(DAY, @CreatedAt, SYSDATETIME());
END
GO


CREATE FUNCTION shop.fn_Product_PriceWithMarkup
    (@Price DECIMAL(10,2), @MarkupPercent DECIMAL(5,2) = 20)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @Price IS NULL OR @Price <= 0 RETURN 0;
    IF @MarkupPercent IS NULL SET @MarkupPercent = 0;
    RETURN @Price * (1 + @MarkupPercent / 100.0);
END
GO


CREATE FUNCTION shop.fn_Orders_ByCustomer (@CustomerId INT)
RETURNS TABLE
AS
RETURN (
    SELECT o.id AS order_id, o.created_at, c.full_name,
           ISNULL(SUM(oi.quantity * oi.price), 0) AS order_total
    FROM shop.orders o
    JOIN shop.customers c ON c.id = o.customer_id
    LEFT JOIN shop.order_items oi ON oi.order_id = o.id
    WHERE o.customer_id = @CustomerId
    GROUP BY o.id, o.created_at, c.full_name
);
GO


CREATE FUNCTION shop.fn_Products_ByCategory (@Category NVARCHAR(50))
RETURNS TABLE
AS
RETURN (
    SELECT id, name, price, quantity FROM shop.products
    WHERE category = @Category AND is_archived = 0
);
GO


CREATE FUNCTION shop.fn_Report_DailyRevenue (@DateFrom DATE, @DateTo DATE)
RETURNS TABLE
AS
RETURN (
    SELECT sale_date, orders_count, items_sold, revenue
    FROM shop.v_daily_revenue
    WHERE sale_date BETWEEN @DateFrom AND @DateTo
);
GO


CREATE TRIGGER shop.trg_Products_Audit_Insert ON shop.products AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop.audit_log (table_name, operation, record_id, old_value, new_value)
    SELECT N'products', N'INSERT', i.id, NULL,
           CONCAT(N'name=', i.name, N'; price=', i.price)
    FROM inserted i;
END
GO


CREATE TRIGGER shop.trg_Products_Audit_Update ON shop.products AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop.audit_log (table_name, operation, record_id, old_value, new_value)
    SELECT N'products', N'UPDATE', i.id,
           CONCAT(N'name=', d.name, N'; price=', d.price),
           CONCAT(N'name=', i.name, N'; price=', i.price)
    FROM inserted i JOIN deleted d ON d.id = i.id;
END
GO


CREATE TRIGGER shop.trg_Products_Audit_Delete ON shop.products AFTER DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop.audit_log (table_name, operation, record_id, old_value, new_value)
    SELECT N'products', N'DELETE', d.id,
           CONCAT(N'name=', d.name, N'; price=', d.price), NULL
    FROM deleted d;
END
GO


CREATE TRIGGER shop.trg_Orders_Audit_Insert ON shop.orders AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop.audit_log (table_name, operation, record_id, new_value)
    SELECT N'orders', N'INSERT', i.id,
           CONCAT(N'customer_id=', i.customer_id)
    FROM inserted i;
END
GO

CREATE TRIGGER shop.trg_Orders_Audit_Delete ON shop.orders AFTER DELETE AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO shop.audit_log (table_name, operation, record_id, old_value)
    SELECT N'orders', N'DELETE', d.id,
           CONCAT(N'customer_id=', d.customer_id)
    FROM deleted d;
END
GO


CREATE TRIGGER shop.trg_OrderItems_CheckStock ON shop.order_items AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN shop.products p ON p.id = i.product_id
        WHERE i.quantity > p.quantity
    )
        THROW 50020, N'Недостаточно товара на складе', 1;
END
GO


CREATE TRIGGER shop.trg_OrderItems_RestoreStock ON shop.order_items AFTER DELETE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p SET p.quantity = p.quantity + d.quantity
    FROM shop.products p
    JOIN deleted d ON d.product_id = p.id;
END
GO


CREATE TRIGGER shop.trg_Products_SoftDelete ON shop.products INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted d
               JOIN shop.order_items oi ON oi.product_id = d.id)
        THROW 50022, N'Нельзя удалить товар, он есть в заказах', 1;

    UPDATE shop.products SET is_archived = 1
    WHERE id IN (SELECT id FROM deleted);

    INSERT INTO shop.audit_log (table_name, operation, record_id, new_value)
    SELECT N'products', N'SOFT_DELETE', d.id, N'is_archived=1'
    FROM deleted d;
END
GO

PRINT N'=== БАЗА ДАННЫХ FlowerShopDB УСПЕШНО СОЗДАНА ===';
PRINT N'Таблиц: 5 (включая audit_log)';
PRINT N'Индексов: 6';
PRINT N'Представлений: 3';
PRINT N'Процедур: 16';
PRINT N'Функций: 8';
PRINT N'Триггеров: 8';
GO

EXEC shop.proc_Products_GetAll;
EXEC shop.proc_Products_GetByName @Name = N'Роза';
EXEC shop.proc_Customers_GetAll;
EXEC shop.proc_Orders_GetByCustomer @CustomerId = 1;
EXEC shop.proc_OrderItems_GetByOrder @OrderId = 1;
GO

EXEC shop.proc_Products_Create @Name = N'Лилия белая', @Category = N'Цветы',
     @Price = 320.00, @Quantity = 40;
EXEC shop.proc_Products_UpdatePrice @ProductId = 1, @NewPrice = 300.00;
GO

DECLARE @NewOrderId INT;
EXEC shop.proc_Orders_Create @CustomerId = 2, @OrderId = @NewOrderId OUTPUT;
PRINT N'Создан заказ №' + CAST(@NewOrderId AS NVARCHAR(10));

DECLARE @Cnt INT;
EXEC shop.proc_Customers_CountOrders @CustomerId = 1, @OrdersCount = @Cnt OUTPUT;
PRINT N'У клиента 1 заказов: ' + CAST(@Cnt AS NVARCHAR(10));
GO
