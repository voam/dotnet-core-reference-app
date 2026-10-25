CREATE TABLE IF NOT EXISTS Products (
    Id    INTEGER PRIMARY KEY AUTOINCREMENT,
    Name  TEXT    NOT NULL,
    Price REAL    NOT NULL
);

INSERT INTO Products (Name, Price) VALUES
    ('Keyboard', 49.99),
    ('Mouse',    19.99),
    ('Monitor', 189.00);
