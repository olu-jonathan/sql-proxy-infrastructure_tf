Create database if not exists openflow_db;
Create schema if not exists openflow_db.setup;

CREATE or replace NETWORK RULE openflow_db.setup.onprem_sql_network_rule
  MODE = EGRESS
  TYPE = PRIVATE_HOST_PORT
  VALUE_LIST = ('sql-private-link-service.025e8053-4736-3125-9528-6a2ea3345257.centralus.azure.privatelinkservice:0');


CREATE EXTERNAL ACCESS INTEGRATION azure_private_access_sql_integration
  ALLOWED_NETWORK_RULES = (onprem_sql_network_rule)
  ENABLED = TRUE;

-- SAMPLE PROCEDURE TO QUERY YOUR SQL SERVER FROM SNOWFLAKE
CREATE OR REPLACE SECRET openflow_db.setup.mssql_secret
TYPE = PASSWORD
USERNAME = ''
PASSWORD = '';

CREATE OR REPLACE PROCEDURE openflow_db.setup.query_sql_server(
    server_host VARCHAR,
    port_number INT,
    database_name VARCHAR,
    query_text VARCHAR
)
    RETURNS TABLE()
    LANGUAGE PYTHON
    RUNTIME_VERSION='3.11'
    HANDLER='run'
    PACKAGES=('snowflake-snowpark-python', 'pyodbc', 'msodbcsql')
    EXTERNAL_ACCESS_INTEGRATIONS = (OPENFLOW_OUT)
    SECRETS = ('cred' = openflow_db.test.mssql_secret)
AS $$
import _snowflake
from snowflake.snowpark import Session
 
def run(session: Session, server_host: str, port_number: int, database_name: str, query_text: str):
    username_password = _snowflake.get_username_password('cred')

    def create_sql_server_connection():
        import pyodbc
        connection_str = (
            "DRIVER={ODBC Driver 18 for SQL Server};"
            f"SERVER={server_host},{port_number};"
            f"DATABASE={database_name};"
            f"UID={username_password.username};"
            f"PWD={username_password.password};"
            "TrustServerCertificate=yes;"
            "Encrypt=yes;"
        )
        return pyodbc.connect(connection_str)

    df = session.read.dbapi(
        create_sql_server_connection,
        query=query_text
    )
    return df
  
$$;

 

--EXAMPLE CALL

CALL openflow_db.setup.query_sql_server(
    'sql-private-link-service.025e8053-4736-3125-9528-6a2ea3345257.centralus.azure.privatelinkservice',
    4002,
    'dbname',
    'SELECT TOP 10 * FROM schema.table'
);
