#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE USER user2 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user2 WITH SUPERUSER;

    CREATE USER user3 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user3 WITH SUPERUSER;

    CREATE USER user4 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user4 WITH SUPERUSER;

    CREATE USER user5 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user5 WITH SUPERUSER;

    CREATE USER user6 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user6 WITH SUPERUSER;
    
    CREATE USER user7 WITH ENCRYPTED PASSWORD 'password';
    ALTER USER user7 WITH SUPERUSER;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE products;
EOSQL


psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    GRANT ALL PRIVILEGES ON DATABASE products TO user2;
    GRANT ALL PRIVILEGES ON DATABASE products TO user3;
    GRANT ALL PRIVILEGES ON DATABASE products TO user4;
    GRANT ALL PRIVILEGES ON DATABASE products TO user5;
    GRANT ALL PRIVILEGES ON DATABASE products TO user6;
    GRANT ALL PRIVILEGES ON DATABASE products TO user7;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "products" <<-EOSQL
    CREATE TABLE IF NOT EXISTS products (
        id CHAR ( 8 ) UNIQUE,
        name VARCHAR ( 255 ),
        category VARCHAR ( 255 ),
        price FLOAT,
        rating FLOAT,
        reviews INTEGER,
        filename VARCHAR ( 255 ) ,
        description TEXT,
        alcoholic VARCHAR ( 255 ),
        temperature VARCHAR ( 255 ),
        type VARCHAR ( 255 )
    );
    COPY products
      ( id, name, filename, description, price, rating, reviews, alcoholic, temperature, type )
    FROM '/docker-entrypoint-initdb.d/products.csv'
    WITH (
      FORMAT csv,
      HEADER
    );
EOSQL
