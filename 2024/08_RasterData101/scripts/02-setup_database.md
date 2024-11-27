# Configure the database for use with GeoRaster

## Steps

I assume, you are still connected as user `opc` to the compute VM via an SSH connection.

Proceed now with the following steps:

1. Connect to the database inside the container

   ```sh
   cd ~
   podman exec -it 23aifree sqlplus sys/${ORACLE_PWD}@localhost:1521/free as sysdba
   ```

   ```sql
   select instance_name, version, status, startup_time from v$instance;
   ```

2. Login to the PDB

   ```sql
   alter session set container = freepdb1;
   select sys_context('userenv', 'con_name') as cur_container from dual;
   ```

3. Add a new tablespace

   ```sql
   create tablespace asktom_tbs datafile 'asktom_tbs01.dbf' size 2G autoextend on next 50M maxsize 5G;
   ```

4. Add a new user

   ```sql
   create user if not exists asktom_user identified by "Welcome_1234#" default tablespace asktom_tbs temporary tablespace temp quota unlimited on asktom_tbs;
   ```

5. Grant privileges to the user

   ```sql
   -- Minimum required permissions
   grant resource, connect to asktom_user;

   -- CREATE TRIGGER is required for enabling GeoRaster at schema level
   grant create trigger to asktom_user;
   ```

6. Logout

   ```sql
   quit
   ```

7. Connect to the database with the new user.

   ```sh
   sqlplus asktom_user/${ORACLE_PWD}@localhost:1521/freepdb1
   ```

8. Enable GeoRaster at schema level

   ```sql
   -- Enable GeoRaster at schema level
   execute sdo_geor_admin.enableGeoRaster;
   -- Verify result
   select /* NO_RESULT_CACHE */ sdo_geor_admin.isGeoRasterEnabled from dual;
   quit
   ```

Proceed now with [enabling client access to your database](./03-open_ports.md).
