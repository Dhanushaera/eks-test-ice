FROM debian:latest
WORKDIR /opt/jease/apache-tomcat-9.0.62/
ENV CATALINA_HOME  /opt/jease/apache-tomcat-9.0.62/
RUN apt-get update
RUN apt-get install wget -y
RUN apt-get install unzip -y
RUN apt-get install systemctl -y
COPY pre-req.sh /
RUN mkdir -p $CATALINA_HOME/webapps/
RUN sh /pre-req.sh
RUN ["rm", "-fr", "$CATALINA_HOME/webapps/ROOT"]
RUN useradd tomcat; chown -R tomcat:tomcat $CATALINA_HOME
RUN chmod -R 777 $CATALINA_HOME/webapps
#COPY jease.war $CATALINA_HOME/webapps/jease.war
#COPY ./db $CATALINA_HOME/db/
ENV JAVA_HOME=/opt/jease/java/
COPY jease.xml $CATALINA_HOME/conf/Catalina/localhost/
EXPOSE 8081
CMD ["/opt/jease/apache-tomcat-9.0.62/bin/catalina.sh", "run"]
