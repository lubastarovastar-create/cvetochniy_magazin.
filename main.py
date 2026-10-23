import tkinter as tk
from tkinter import ttk, messagebox
import sqlite3
import os
import unittest

DB_NAME = 'flowershop.db'
SCHEMA = 'flowershop_schema.sql'

def get_conn():
    return sqlite3.connect(DB_NAME)

def init_db():
    if not os.path.exists(DB_NAME):
        with get_conn() as conn:
            with open(SCHEMA, 'r', encoding='utf-8') as f:
                conn.executescript(f.read())
        # Начальные данные
        with get_conn() as conn:
            conn.execute("INSERT INTO products (name, category, price, quantity) VALUES ('Роза', 'Цветы', 250, 100)")
            conn.execute("INSERT INTO customers (full_name, phone) VALUES ('Иванов Иван', '+79001112233')")


def add_product(name, cat, price, qty):
    with get_conn() as c:
        c.execute("INSERT INTO products (name, category, price, quantity) VALUES (?,?,?,?)", (name, cat, price, qty))

def get_products():
    with get_conn() as c:
        return c.execute("SELECT id, name, category, price, quantity FROM products").fetchall()

def add_customer(name, phone):
    with get_conn() as c:
        c.execute("INSERT INTO customers (full_name, phone) VALUES (?,?)", (name, phone))

def get_customers():
    with get_conn() as c:
        return c.execute("SELECT id, full_name FROM customers").fetchall()

def create_order(cust_id, prod_id, qty):
    with get_conn() as c:
        
        cur = c.execute("INSERT INTO orders (customer_id) VALUES (?)", (cust_id,))
        order_id = cur.lastrowid
      
        price = c.execute("SELECT price FROM products WHERE id=?", (prod_id,)).fetchone()[0]
       
        c.execute("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?,?,?,?)", 
                  (order_id, prod_id, qty, price))

def get_orders():
    with get_conn() as c:
        return c.execute('''
            SELECT o.id, c.full_name, p.name, oi.quantity, (oi.quantity * oi.price)
            FROM orders o
            JOIN customers c ON c.id = o.customer_id
            JOIN order_items oi ON oi.order_id = o.id
            JOIN products p ON p.id = oi.product_id
        ''').fetchall()


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Цветочный магазин (Простая версия)")
        
        tabs = ttk.Notebook(root)
        tabs.pack(fill='both', expand=True)
        
        self.t1 = tk.Frame(tabs); tabs.add(self.t1, text='Товары')
        self.t2 = tk.Frame(tabs); tabs.add(self.t2, text='Покупатели')
        self.t3 = tk.Frame(tabs); tabs.add(self.t3, text='Заказы')
        
        self.setup_tab1()
        self.setup_tab2()
        self.setup_tab3()

    def setup_tab1(self):
        f = tk.Frame(self.t1); f.pack(pady=5)
        tk.Label(f, text="Название:").pack(side='left')
        self.e_name = tk.Entry(f); self.e_name.pack(side='left')
        tk.Label(f, text="Цена:").pack(side='left')
        self.e_price = tk.Entry(f, width=10); self.e_price.pack(side='left')
        tk.Label(f, text="Кол-во:").pack(side='left')
        self.e_qty = tk.Entry(f, width=10); self.e_qty.pack(side='left')
        tk.Button(f, text="Добавить", command=self.add_prod).pack(side='left')
        
        self.tree1 = ttk.Treeview(self.t1, columns=('ID','Название','Цена','Остаток'), show='headings')
        for col in self.tree1['columns']: self.tree1.heading(col, text=col)
        self.tree1.pack(fill='both', expand=True)
        self.refresh_prods()

    def add_prod(self):
        try:
            add_product(self.e_name.get(), 'Цветы', float(self.e_price.get()), int(self.e_qty.get()))
            self.refresh_prods()
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_prods(self):
        for i in self.tree1.get_children(): self.tree1.delete(i)
        for row in get_products(): self.tree1.insert('', 'end', values=(row[0], row[1], row[3], row[4]))

    def setup_tab2(self):
        f = tk.Frame(self.t2); f.pack(pady=5)
        tk.Label(f, text="ФИО:").pack(side='left')
        self.c_name = tk.Entry(f); self.c_name.pack(side='left')
        tk.Label(f, text="Телефон:").pack(side='left')
        self.c_phone = tk.Entry(f); self.c_phone.pack(side='left')
        tk.Button(f, text="Добавить", command=self.add_cust).pack(side='left')
        
        self.tree2 = ttk.Treeview(self.t2, columns=('ID','ФИО','Телефон'), show='headings')
        for col in self.tree2['columns']: self.tree2.heading(col, text=col)
        self.tree2.pack(fill='both', expand=True)
        self.refresh_custs()

    def add_cust(self):
        try:
            add_customer(self.c_name.get(), self.c_phone.get())
            self.refresh_custs()
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_custs(self):
        for i in self.tree2.get_children(): self.tree2.delete(i)
        for row in get_customers(): self.tree2.insert('', 'end', values=row)

    def setup_tab3(self):
        f = tk.Frame(self.t3); f.pack(pady=5)
        tk.Button(f, text="Оформить тестовый заказ (клиент 1, товар 1, 3 шт)", command=self.mock_order).pack()
        
        self.tree3 = ttk.Treeview(self.t3, columns=('ID','Клиент','Товар','Кол-во','Сумма'), show='headings')
        for col in self.tree3['columns']: self.tree3.heading(col, text=col)
        self.tree3.pack(fill='both', expand=True)
        self.refresh_orders()

    def mock_order(self):
        try:
            create_order(1, 1, 3) # Берем первого клиента и товар
            self.refresh_orders()
            messagebox.showinfo("Успех", "Заказ создан! Остаток товара уменьшился.")
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_orders(self):
        for i in self.tree3.get_children(): self.tree3.delete(i)
        for row in get_orders(): self.tree3.insert('', 'end', values=row)


class TestApp(unittest.TestCase):
    def setUp(self):
       
        self.old_db = DB_NAME
        globals()['DB_NAME'] = ':memory:'
        init_db()

    def tearDown(self):
        globals()['DB_NAME'] = self.old_db

    def test_add_product(self):
        add_product('Тест', 'Цветы', 100, 10)
        self.assertEqual(len(get_products()), 2) # 1 стартовая + 1 новая

    def test_order_trigger(self):
   
        create_order(1, 1, 5) 
       
        prods = get_products()
        self.assertEqual(prods[0][4], 95)

if __name__ == '__main__':
    import sys
    if '--test' in sys.argv:
        unittest.main(argv=['first-arg-is-ignored'], exit=False)
    else:
        init_db()
        root = tk.Tk()
        app = App(root)
        root.mainloop()
