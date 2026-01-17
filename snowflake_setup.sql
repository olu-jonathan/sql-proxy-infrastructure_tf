CREATE or replace NETWORK RULE onprem_sql_network_rule
  MODE = EGRESS
  TYPE = PRIVATE_HOST_PORT
  VALUE_LIST = ('sql-private-link-service.025e8053-4736-3125-9528-6a2ea3345257.centralus.azure.privatelinkservice:0');


CREATE EXTERNAL ACCESS INTEGRATION azure_private_access_sql_integration
  ALLOWED_NETWORK_RULES = (onprem_sql_network_rule)
  ENABLED = TRUE;
