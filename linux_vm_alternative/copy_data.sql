-- TO copy from sql server using a proc

CREATE OR REPLACE SECRET openflow_db.setup.mssql_secret
TYPE = PASSWORD
USERNAME = ''
PASSWORD = '';

-- Step 2: Ensure network rule includes the private endpoint and the EAI uses it.

CREATE OR REPLACE PROCEDURE OPENFLOW_DB.SETUP.COPY_SQL_SERVER_TABLE(
    "SERVER_HOST" VARCHAR,
    "PORT_NUMBER" NUMBER(8,0),
    "SQL_SERVER_DB" VARCHAR,
    "SQL_SERVER_SCHEMA" VARCHAR,
    "SQL_SERVER_TABLE" VARCHAR,
    "SNOW_DB" VARCHAR,
    "SNOW_SCHEMA" VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python','pyodbc','msodbcsql')
HANDLER = 'run'
EXTERNAL_ACCESS_INTEGRATIONS = (OPENFLOW_OUT)
SECRETS = ('cred'=OPENFLOW_DB.SETUP.MSSQL_SECRET)
EXECUTE AS OWNER
AS '
import _snowflake
from snowflake.snowpark import Session

def run(session: Session, server_host: str, port_number: int, sql_server_db: str, sql_server_schema: str, sql_server_table: str, snow_db: str, snow_schema: str):
    username_password = _snowflake.get_username_password(''cred'')
    
    def create_sql_server_connection():
        import pyodbc
        connection_str = (
            "DRIVER={ODBC Driver 18 for SQL Server};"
            f"SERVER={server_host},{port_number};"
            f"DATABASE={sql_server_db};"
            f"UID={username_password.username};"
            f"PWD={username_password.password};"
            "TrustServerCertificate=yes;"
            "Encrypt=yes;"
        )
        return pyodbc.connect(connection_str)
    
    query_text = f"SELECT * FROM [{sql_server_schema}].[{sql_server_table}]"
    
    df = session.read.dbapi(
        create_sql_server_connection,
        query=query_text
    )
    
    full_table_name = f"{snow_db}.{snow_schema}.{sql_server_table}"
    df.write.mode("overwrite").save_as_table(full_table_name)
    
    row_count = session.table(full_table_name).count()
    return f"Successfully created {full_table_name} with {row_count} rows"
';



CALL OPENFLOW_DB.SETUP.COPY_SQL_SERVER_TABLE(
    'your-server.database.windows.net',  -- SERVER_HOST
    1433,                                  -- PORT_NUMBER
    'SourceDB',                            -- SQL_SERVER_DB
    'dbo',                                 -- SQL_SERVER_SCHEMA
    'Customers',                           -- SQL_SERVER_TABLE
    'OPENFLOW_DB',                         -- SNOW_DB
    'PUBLIC'                               -- SNOW_SCHEMA
);
