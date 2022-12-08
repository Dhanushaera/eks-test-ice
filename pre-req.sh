#### Jease Preparation script
# This script prepares a gold-build Linux server to run Jease
#



APP=jease
APPDIR=/opt/$APP
TOMCAT_VERSION="9.0.62"
CORRETTO_VERSION="11.0.12.7.1"
#Fallback Version#CORRETTO_VERSION="8.332.08.1"



mkdir -p $APPDIR



wget https://corretto.aws/downloads/resources/$CORRETTO_VERSION/amazon-corretto-$CORRETTO_VERSION-linux-x64.tar.gz -LO /opt/java.tar.gz
tar xpf /opt/java.tar.gz -C $APPDIR
ln -s $APPDIR/amazon-corretto-$CORRETTO_VERSION-linux-x64/ $APPDIR/java
chmod +x $APPDIR/java/bin/*



# Download Tomcat
wget https://archive.apache.org/dist/tomcat/tomcat-9/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.zip -LO /opt/tomcat.zip
unzip /opt/tomcat.zip -d $APPDIR/
rm -f /opt/tomcat.zip
ln -s $APPDIR/apache-tomcat-$TOMCAT_VERSION/ $APPDIR/apache-tomcat
chmod +x $APPDIR/apache-tomcat/bin/*.sh



# Tomcat will do this at first-run, but it allows us to deploy before running
mkdir -p $APPDIR/apache-tomcat/conf/Catalina/localhost



# Remove all the default webapps that ship with tomcat
rm -rf $APPDIR/apache-tomcat/webapps/*



# Provide a root index for the ALB health checks
mkdir -p $APPDIR/apache-tomcat/webapps/ROOT
cat >$APPDIR/apache-tomcat/webapps/ROOT/index.html <<EOF
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
  </head>
  <body>
    <p> Server is healthy </p>
  </body>
</html>
EOF



# Set Jease's database directory
cat >$APPDIR/apache-tomcat/conf/Catalina/localhost/jease.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context>
  <Parameter name="JEASE_DATABASE_NAME" value="$APPDIR/db" override="1"/>
</Context>
EOF



# Service user
SVCUSER=svc-$APP
useradd -Mr $SVCUSER -d $APPDIR -c "$APP service user"
chown $SVCUSER.$SVCUSER -R $APPDIR



# Create a systemd service
cat >/etc/systemd/system/$APP.service <<EOF
[Unit]
Description=Seaware $APP Tomcat application



[Service]
User=$SVCUSER
Group=$SVCUSER
EnvironmentFile=/etc/default/$APP
WorkingDirectory=$APPDIR/apache-tomcat
ExecStart=$APPDIR/apache-tomcat/bin/catalina.sh run 2>$APPDIR/apache-tomcat/logs/stderr.last
SuccessExitStatus=143
StandardOutput=journal
StandardError=journal+console
ProtectSystem=full
Restart=on-failure



# We have to use an old version of systemd, so we use PermissionsStartOnly
# The better way to do this is with +cmds, but they are not supported in AL2
PermissionsStartOnly=true
ExecStartPre=/bin/chown -R $SVCUSER:$SVCUSER $APPDIR
ExecStartPre=/bin/chmod -R 770 $APPDIR



[Install]
WantedBy=multi-user.target
EOF



# Set the environment variables for Jease
cat >/etc/default/$APP <<EOF
JAVA_HOME="$APPDIR/java"
JAVA_OPTS=" \\
    -Djava.awt.headless=true \\
    -Xms2048m -Xmx2048m \\
    -XX:+UseConcMarkSweepGC"
EOF



# Set the logging properties
cat >>$APPDIR/apache-tomcat/conf/logging.properties <<EOF



# Configure Tomcat to remove dates from logs, so logrotate can do its job
# Because the date is missing we also need to stop the files having two 'dots'
1catalina.org.apache.juli.AsyncFileHandler.suffix        = log
1catalina.org.apache.juli.AsyncFileHandler.rotatable     = false
2localhost.org.apache.juli.AsyncFileHandler.suffix       = log
2localhost.org.apache.juli.AsyncFileHandler.rotatable    = false
3manager.org.apache.juli.AsyncFileHandler.suffix         = log
3manager.org.apache.juli.AsyncFileHandler.rotatable      = false
4host-manager.org.apache.juli.AsyncFileHandler.suffix    = log
4host-manager.org.apache.juli.AsyncFileHandler.rotatable = false
EOF



# TODO: We need to configure /conf/server.xml to disable rotatable on the funnel
# Editing XML is hard so we'll script it using some inline python or something
# We want to change the AccessLogValve to the following:
# <Valve  className="org.apache.catalina.valves.AccessLogValve"
#     directory="logs"
#     prefix="localhost_access_log"
#     suffix=".log"
#     rotatable="false"
# />



# We need to change the listening port, touch has 8080, this should be 8081
mv -f $APPDIR/apache-tomcat/conf/server.xml $APPDIR/apache-tomcat/conf/server.xml.bak
cat $APPDIR/apache-tomcat/conf/server.xml.bak \
| perl -pe '$_=~s/(<Connector port=")(8080)(")/${1}8081$3/' \
> $APPDIR/apache-tomcat/conf/server.xml



# We also need to change the listening port of the tomcat service itself
mv -f $APPDIR/apache-tomcat/conf/server.xml $APPDIR/apache-tomcat/conf/server.xml.bak
cat $APPDIR/apache-tomcat/conf/server.xml.bak \
| perl -pe '$_=~s/(<Server port=")(8005)(")/${1}8015$3/' \
> $APPDIR/apache-tomcat/conf/server.xml





# Configure logrotate
cat >/etc/logrotate.d/$APP <<EOF
$APPDIR/apache-tomcat/logs/catalina.log {
    su $SVCUSER $SVCUSER
    daily
    rotate 7
    notifempty
    copytruncate
    compress
    missingok
}
$APPDIR/apache-tomcat/logs/host-manager.log {
    su $SVCUSER $SVCUSER
    daily
    rotate 7
    notifempty
    copytruncate
    compress
    missingok
}
$APPDIR/apache-tomcat/logs/localhost.log {
    su $SVCUSER $SVCUSER
    daily
    rotate 7
    notifempty
    copytruncate
    compress
    missingok
}
$APPDIR/apache-tomcat/logs/localhost_access_log.log {
    su $SVCUSER $SVCUSER
    daily
    rotate 7
    notifempty
    copytruncate
    compress
    missingok
}
$APPDIR/apache-tomcat/logs/manager.log {
    su $SVCUSER $SVCUSER
    daily
    rotate 7
    notifempty
    copytruncate
    compress
    missingok
}
EOF



# Configure this service to start on boot
systemctl enable $APP.service
