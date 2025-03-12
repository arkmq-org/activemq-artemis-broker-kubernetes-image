#!/bin/sh
set -e

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
SOURCES_DIR="/tmp/artifacts"
DEST=$AMQ_HOME

mkdir -p ${DEST}
mkdir -p ${DEST}/conf/

if ! ls $AMQ_HOME/lib/artemis-prometheus-metrics-plugin*.jar; then
  curl --fail -L --output "$AMQ_HOME/lib/artemis-prometheus-metrics-plugin-2.0.0.redhat-00002.jar" https://maven.repository.redhat.com/ga/com/redhat/amq-broker/artemis-prometheus-metrics-plugin/2.0.0.redhat-00002/artemis-prometheus-metrics-plugin-2.0.0.redhat-00002.jar
fi

if ! ls $AMQ_HOME/web/metrics.war; then
  curl --fail -L --output "$AMQ_HOME/web/metrics.war" https://maven.repository.redhat.com/ga/com/redhat/amq-broker/artemis-prometheus-metrics-plugin-servlet/2.0.0.redhat-00002/artemis-prometheus-metrics-plugin-servlet-2.0.0.redhat-00002.war
fi

if ! ls $AMQ_HOME/lib/keycloak-adapter-core*.jar; then
  curl -L --output "$AMQ_HOME/lib/bcprov-jdk15on-1.70.jar" https://repo.maven.apache.org/maven2/org/bouncycastle/bcprov-jdk15on/1.70/bcprov-jdk15on-1.70.jar
  curl -L --output "$AMQ_HOME/lib/bcpkix-jdk15on-1.70.jar" https://repo.maven.apache.org/maven2/org/bouncycastle/bcpkix-jdk15on/1.70/bcpkix-jdk15on-1.70.jar
  curl -L --output "$AMQ_HOME/lib/commons-codec-1.15.jar" https://repo.maven.apache.org/maven2/commons-codec/commons-codec/1.15/commons-codec-1.15.jar
  curl -L --output "$AMQ_HOME/lib/commons-logging-1.2.jar" https://repo.maven.apache.org/maven2/commons-logging/commons-logging/1.2/commons-logging-1.2.jar
  curl -L --output "$AMQ_HOME/lib/httpclient-4.5.13.jar" https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpclient/4.5.13/httpclient-4.5.13.jar
  curl -L --output "$AMQ_HOME/lib/httpcore-4.4.16.jar" https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpcore/4.4.16/httpcore-4.4.16.jar
  curl -L --output "$AMQ_HOME/lib/jackson-annotations-2.14.2.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.14.2/jackson-annotations-2.14.2.jar
  curl -L --output "$AMQ_HOME/lib/jackson-core-2.14.2.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-core/2.14.2/jackson-core-2.14.2.jar
  curl -L --output "$AMQ_HOME/lib/jackson-databind-2.14.2.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.14.2/jackson-databind-2.14.2.jar
  curl -L --output "$AMQ_HOME/lib/jakarta.activation-1.2.2.jar" https://repo.maven.apache.org/maven2/com/sun/activation/jakarta.activation/1.2.2/jakarta.activation-1.2.2.jar
  curl -L --output "$AMQ_HOME/lib/jboss-logging-3.5.0.Final.jar" https://repo.maven.apache.org/maven2/org/jboss/logging/jboss-logging/3.5.0.Final/jboss-logging-3.5.0.Final.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-adapter-core-18.0.2.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-adapter-core/18.0.2/keycloak-adapter-core-18.0.2.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-common-18.0.2.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-common/18.0.2/keycloak-common-18.0.2.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-core-18.0.2.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-core/18.0.2/keycloak-core-18.0.2.jar
fi

cp -p ${SOURCES_DIR}/netty-tcnative*.jar \
  ${DEST}/lib

cp -p $ADDED_DIR/jgroups-ping.xml \
  ${DEST}/conf/

cp -p $ADDED_DIR/log4j2.properties \
  ${DEST}/conf/

cp $ADDED_DIR/launch.sh \
  ${ADDED_DIR}/readinessProbe.sh \
  ${ADDED_DIR}/drain.sh \
  $AMQ_HOME/bin

chmod 0755 $AMQ_HOME/bin/launch.sh
chmod 0755 $AMQ_HOME/bin/readinessProbe.sh
chmod 0755 $AMQ_HOME/bin/drain.sh
ln -s /opt/agents/jolokia.jar  /opt/jolokia/javaagent.jar
