# Deploy GeoServer 22.4.2 on Tomcat 9

## Environment info

Oracle Cloud Infrastructure

## Prerequisites

1. Create a VCN

2. Create a compute VM with OEL8 or 9

## Deployment

Follow the steps described [here](https://learnoci.cloud/how-to-create-a-tomcat-server-in-oci-and-expose-it-to-the-internet-using-oci-load-balancer-7830a15d5afd) by Alex Birzu.

Alternate descriptions:

* [How to install GeoServer with Apache Tomcat 9 on Linux Ubuntu?](https://gisgeeks.com/how-to-install-geoserver-with-apache-tomcat-9-on-linux-ubuntu/)

### Steps

1. Test the connection to your Linux instance

    * Follow the instructions given [here](https://blogs.oracle.com/oracleuniversity/post/access-compute-instances-oracle-cloud-shell).

2. Download Java

    * JDK17
    * Copy the rpm file to your compute instance into folder /tmp

3. Install Java

    Login as user opc to your compute instance.

    ```sh
    cd /tmp
    sudo rpm -ivh jdk-17_linux-x64_bin.rpm
    ll /usr/java
    sudo alternatives --install /usr/bin/java java /usr/java/jdk-17/bin/java 200000
    sudo alternatives --config java
    java -version
    ```

4. Download Tomcat9

5. Install Tomcat9

    ```sh
    sudo useradd tomcat
    sudo mkdir -p /apps
    sudo chown tomcat:tomcat /apps
    sudo su - tomcat
    sudo mv apache-tomcat-9.0.85.tar.gz /apps/
    tar xzf /apps/apache-tomcat-9.0.85.tar.gz
    sudo mv apache-tomcat-9.0.85 /apps/tomcat
    sudo chown -R tomcat:tomcat /apps
    sudo su - tomcat
    cat /etc/systemd/system/tomcat.service
    ps -ef | grep tomcat
    ```

    Set CATALINA_HOME

    Add the following text to /home/tomcat/.bash_profile

    ```txt
    export CATALINA_HOME=/apps/tomcat
    ```

    Then run

    ```sh
    source /home/tomcat/.bash_profile
    ```

6. Configure Admin users

    ```sh
    sudo nano $CATALINA_HOME/conf/tomcat-users.xml
    ```

7. Open ports

    ```sh
    sudo firewall-cmd --list-ports
    sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=8443/tcp --permanent
    sudo firewall-cmd --reload
    ```

8. Check Tomcat

    * [Open Tomcat in browser](http://130.61.103.27:8080/)

    If Tomcat is not running, then:

    ```sh
    cd $CATALINA_HOME/bin
    sh startup.sh
    ```

9. Set up a JNDI connection pool

    Setting up a connection pool requires the JDBC driver for your database. Check their availability [here](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html).

    Download the driver and move the .jar files into $CATALINA_HOME/lib.

    ```sh
    cd /tmp
    wget https://download.oracle.com/otn-pub/otn_software/jdbc/233/ojdbc11.jar
    mv ojdbc11.jar $CATALINA_HOME/lib
    ```

    Edit $CATALINA_HOME/conf/server.xml. Add the following:

    ```txt
    <Resource name="jdbc/demodb"
      auth="Container"
      global="jdbc/demodb"
      type="javax.sql.DataSource"
      driverClassName="oracle.jdbc.driver.OracleDriver"
      url="jdbc:oracle:thin:@(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=ij1tyzir3wpwlpe_demodb_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
      username="spatialuser" password="..."
      maxTotal="20"
      maxIdle="8"
      validationQuery="SELECT SYSDATE FROM DUAL"
      maxWaitMillis="-1"
    />
    ```

    Edit $CATALINA_HOME/conf/context.xml. Add the following:

    ```txt
    <ResourceLink name="jdbc/demodb"
        global="jdbc/demodb"
        auth="Container"
        type="javax.sql.DataSource" />
    ```

    Restart Tomcat

    ```sh
    cd $CATALINA_HOME/bin
    sh shutdown.sh
    sh startup.sh
    ```

10. Download and deploy GeoServer

    * Open the [Download page](https://geoserver.org/)
    * [Download the .war file](https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.2/geoserver-2.24.2-war.zip)

    ```sh
    cd /tmp
    wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.2/geoserver-2.24.2-war.zip
    cd $CATALINA_HOME/webapps
    unzip /tmp/geoserver-2.22.4-war.zip
    ```

    Avoid conflicts with JDBC driver

    ```sh
    cd $CATALINA_HOME/webapps/geoserver/WEB-INF/lib
    mv ojdbc8-19.18.0.0.jar ojdbc8-19.18.0.0.jar.bck
    ```

11. Start GeoServer

    * [Open GeoServer in browser](http://130.61.103.27:8080/geoserver)

    Note: The default administration credentials are:

    * User name: admin
    * Password: default is "geoserver" (changed to "Welcome123#")

    Check the [documentation](https://docs.geoserver.org/stable/en/user/index.html) for any further information on GeoServer 2.24.x.

12. Download and install Oracle extension

    ```sh
    cd /tmp
    wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.2/extensions/geoserver-2.24.2-oracle-plugin.zip
    cd $CATALINA_HOME/webapps/geoserver/WEB-INF/lib
    unzip /tmp/unzip /tmp/geoserver-2.24.2-oracle-plugin.zip
    ```

    * [Download page for the Oracle plugin for GeoServer](https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.2/extensions/geoserver-2.24.2-oracle-plugin.zip/download)
    * Follow the instructions given [here](https://docs.geoserver.org/main/en/user/data/database/oracle.html)
    * Restart Tomcat

    ```sh
    sh $CATALINA_HOME/shutdown.sh
    sh $CATALINA_HOME/startup.sh
    ```

13. Add an Oracle Datastore

    * Add new store
    * To connect to an Autonomous Database, select Oracle NG (JNDI)
    * [Documentation](https://docs.geoserver.org/main/en/user/data/database/oracle.html)

14. Change the default password for user ADMIN

    * On the GeoServer Console, go to:

        * Security > Users, Groups, Roles
        * Choose tab "USers/Groups"
        * Edit user "admin"
        * Change the password and save your changes

    * Close the GeoServer Console.
    * Open the GeoServer Console in a new browser window or tab.

15. Advanced security topics

    * To set up a keystore for your passwords, follow the instructions in the [documentation](https://docs.geoserver.org/stable/en/user/security/passwd.html).

    ```sh
    cd /apps/tomcat/webapps/geoserver/data/security
    locate keytool
    /usr/lib/jvm/jdk-17-oracle-x64/bin/keytool -list -keystore geoserver.jceks -storetype "JCEKS"
    ...
    ...
    ```

### More information

Other links to check:

* [https://www.youtube.com/watch?v=L7I2nPJs9E0](https://www.youtube.com/watch?v=L7I2nPJs9E0)
* [https://www.youtube.com/watch?v=Foj3XXlEQFA](https://www.youtube.com/watch?v=Foj3XXlEQFA)
