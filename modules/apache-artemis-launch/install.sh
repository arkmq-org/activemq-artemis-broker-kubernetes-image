#!/bin/sh
set -e

SCRIPT_DIR=$(dirname $0)
ADDED_DIR=${SCRIPT_DIR}/added
SOURCES_DIR="/tmp/artifacts"
DEST=$AMQ_HOME

mkdir -p ${DEST}
mkdir -p ${DEST}/conf/

if ! ls $AMQ_HOME/lib/artemis-prometheus-metrics-plugin*.jar; then
  curl --fail -L --output "$AMQ_HOME/lib/artemis-prometheus-metrics-plugin-3.1.0.jar" https://github.com/rh-messaging/artemis-prometheus-metrics-plugin/releases/download/v3.1.0/artemis-prometheus-metrics-plugin-3.1.0.jar
fi

if ! ls $AMQ_HOME/web/metrics.war; then
  curl --fail -L --output "$AMQ_HOME/web/metrics.war" https://github.com/rh-messaging/artemis-prometheus-metrics-plugin/releases/download/v3.1.0/metrics.war
fi

if ! ls $AMQ_HOME/lib/keycloak-adapter-core*.jar; then
  curl -L --output "$AMQ_HOME/lib/bcprov-jdk18on-1.83.jar" https://repo.maven.apache.org/maven2/org/bouncycastle/bcprov-jdk18on/1.83/bcprov-jdk18on-1.83.jar
  curl -L --output "$AMQ_HOME/lib/commons-codec-1.21.0.jar" https://repo.maven.apache.org/maven2/commons-codec/commons-codec/1.21.0/commons-codec-1.21.0.jar
  curl -L --output "$AMQ_HOME/lib/commons-logging-1.3.5.jar" https://repo.maven.apache.org/maven2/commons-logging/commons-logging/1.3.5/commons-logging-1.3.5.jar
  curl -L --output "$AMQ_HOME/lib/httpclient-4.5.14.jar" https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpclient/4.5.14/httpclient-4.5.14.jar
  curl -L --output "$AMQ_HOME/lib/httpcore-4.4.16.jar" https://repo.maven.apache.org/maven2/org/apache/httpcomponents/httpcore/4.4.16/httpcore-4.4.16.jar
  curl -L --output "$AMQ_HOME/lib/jackson-annotations-2.21.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.21/jackson-annotations-2.21.jar
  curl -L --output "$AMQ_HOME/lib/jackson-core-2.21.0.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-core/2.21.0/jackson-core-2.21.0.jar
  curl -L --output "$AMQ_HOME/lib/jackson-databind-2.21.0.jar" https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.21.0/jackson-databind-2.21.0.jar
  curl -L --output "$AMQ_HOME/lib/jakarta.activation-1.2.2.jar" https://repo.maven.apache.org/maven2/com/sun/activation/jakarta.activation/1.2.2/jakarta.activation-1.2.2.jar
  curl -L --output "$AMQ_HOME/lib/jboss-logging-3.5.3.Final.jar" https://repo.maven.apache.org/maven2/org/jboss/logging/jboss-logging/3.5.3.Final/jboss-logging-3.5.3.Final.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-adapter-core-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-adapter-core/24.0.5/keycloak-adapter-core-24.0.5.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-common-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-common/24.0.5/keycloak-common-24.0.5.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-core-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-core/24.0.5/keycloak-core-24.0.5.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-crypto-default-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-crypto-default/24.0.5/keycloak-crypto-default-24.0.5.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-server-spi-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-server-spi/24.0.5/keycloak-server-spi-24.0.5.jar
  curl -L --output "$AMQ_HOME/lib/keycloak-server-spi-private-24.0.5.jar" https://repo.maven.apache.org/maven2/org/keycloak/keycloak-server-spi-private/24.0.5/keycloak-server-spi-private-24.0.5.jar
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
