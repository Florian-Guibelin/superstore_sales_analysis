/* Création des tables */

CREATE TABLE df_dim_customer (
    customer_id        VARCHAR(8) PRIMARY KEY,
    customer_name      VARCHAR(100),
    segment            VARCHAR(50)
);

CREATE TABLE df_dim_location (
	location_id        VARCHAR(8)  PRIMARY KEY,
    city               VARCHAR(100),
    state              VARCHAR(100),
    postal_code        VARCHAR(5),
    region             VARCHAR(50)
);

CREATE TABLE df_dim_product (
    product_id         VARCHAR(16) PRIMARY KEY,
    category           VARCHAR(50),
    sub_category       VARCHAR(50),
    product_name       VARCHAR(255),
    price              DECIMAL(10,2),
    unit_cost          DECIMAL(10,2)
);

CREATE TABLE df_facts (
    order_id           VARCHAR(14),
    order_date         DATE,
    ship_date          DATE,
    ship_mode          VARCHAR(50),
    customer_id        VARCHAR(8),
    location_id        VARCHAR(8),
    product_id         VARCHAR(16),
    quantity           INT,
    total_sales        DECIMAL(12,2),
    discount           DECIMAL(5,2),
    profit             DECIMAL(12,2),
    upm_pre_discount   DECIMAL(10,2),
    upm_post_discount  DECIMAL(10,2),

    PRIMARY KEY (order_id, product_id, quantity),

    FOREIGN KEY (customer_id)
        REFERENCES df_dim_customer(customer_id),
	
    FOREIGN KEY (location_id)
		REFERENCES df_dim_location(location_id),

    FOREIGN KEY (product_id)
        REFERENCES df_dim_product(product_id)
);
