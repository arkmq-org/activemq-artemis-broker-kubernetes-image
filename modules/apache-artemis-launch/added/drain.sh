#!/usr/bin/env bash

if [ -z "${DRAINER_HOST}" ]; then
  echo "[drain.sh] DRAINER_HOST is not set"
  sleep 30
  exit 1
fi

# use pod IP rather than `hostname -f` which will return pod's name
# that is not resolvable across the cluster
export BROKER_HOST=${DRAINER_HOST}

echo "[drain.sh] drainer container ip is $BROKER_HOST"

instanceDir="${HOME}/${AMQ_NAME}"

ENDPOINT_NAME="${AMQ_NAME}-amq-headless"

if [ "$HEADLESS_SVC_NAME" ]; then
  ENDPOINT_NAME=$HEADLESS_SVC_NAME
fi

endpointsUrl="https://${KUBERNETES_SERVICE_HOST:-kubernetes.default.svc}:${KUBERNETES_SERVICE_PORT:-443}/api/v1/namespaces/${POD_NAMESPACE}/"
endpointsAuth="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"

function waitForJolokia() {
  while : ;
  do
    sleep 5
    curl -s -o /dev/null -G -k "http://${AMQ_USER}:${AMQ_PASSWORD}@${BROKER_HOST}:8161/console/jolokia"
    if [ $? -eq 0 ]; then
      break
    fi
  done
}


endpointsCode=$(curl -s -o /dev/null -w "%{http_code}" -G -k -H "${endpointsAuth}" "${endpointsUrl}")
if [ "$endpointsCode" -ne 200 ]; then
  echo "[drain.sh] Can't find endpoints with ips status <${endpointsCode}>"
  exit 1
fi

ENDPOINTS=$(curl -s -X GET -G -k -H "${endpointsAuth}" "${endpointsUrl}endpoints/${ENDPOINT_NAME}")
echo "[drain.sh] $ENDPOINTS"
# we will find out a broker pod's fqdn name which is <pod-name>.<$HEADLESS_SVC_NAME>.<namespace>.svc.<domain-name>
# https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
count=0
foundTarget="false"
while true; do
  ip=$(echo "$ENDPOINTS" | jq --argjson count ${count} -r '.subsets[0].addresses[$count].ip')
  if [ $? -ne 0 ]; then
    echo "[drain.sh] Can't find ip to scale down to tried ${count} ips"
    exit 1
  fi
  echo "[drain.sh] got ip ${ip} broker ip is ${BROKER_HOST}"
  podName=$(echo "$ENDPOINTS" | jq --argjson count ${count} -r '.subsets[0].addresses[$count].targetRef.name')
  if [ $? -ne 0 ]; then
    echo "[drain.sh] Can't find pod name to scale down to tried ${count}"
    exit 1
  fi
  echo "[drain.sh] got podName ${podName} broker ip is ${BROKER_HOST}"
  if [ "$podName" != "$BROKER_HOST" ]; then
    # found an endpoint pod as a candidate for scaledown target
    podNamespace=$(echo "$ENDPOINTS" | jq --argjson count ${count} -r '.subsets[0].addresses[$count].targetRef.namespace')
    if [ $? -ne 0 ]; then
      echo "[drain.sh] Can't find pod namespace to scale down to tried ${count}"
      exit 1
    fi
    foundTarget="true"
    break
  fi

  count=$(( count + 1 ))
done

if [ "$foundTarget" == "false" ]; then
  echo "[drain.sh] Can't find a target to scale down to"
  exit 1
fi

# get host name of target pod
IFSP=$IFS
IFS=
dnsNames=$(nslookup "${ip}")
echo "[drain.sh] $dnsNames"

hostNamePrefix="${podName}.${HEADLESS_SVC_NAME}.${podNamespace}.svc."
echo "[drain.sh] searching hostname with prefix: $hostNamePrefix"

while read -r line
do
  IFS=' ' read -ra ARRAY <<< "$line"
  if [ ${#ARRAY[@]} -gt 0 ]; then
    hostName=${ARRAY[-1]}
    if [[ $hostName == ${hostNamePrefix}* ]]; then
      # remove the last dot
      case $hostName in *.) hostName=${hostName%"."};; esac
      echo "[drain.sh] found hostname: $hostName"
      break
    fi
  fi
done <<< "${dnsNames}"
IFS=$IFSP

if [ -z "$hostName" ]; then
  echo "[drain.sh] Can't find target host name"
  exit 1
fi

# shellcheck source=/dev/null
source /opt/amq/bin/launch.sh nostart

SCALE_TO_BROKER="${hostName}"
echo "[drain.sh] scale down target is: $SCALE_TO_BROKER"

# Add connector to the pod to scale down to
connector="<connector name=\"scaledownconnector\">tcp:\/\/${SCALE_TO_BROKER}:61616<\/connector>"
sed -i "/<\/connectors>/ s/.*/${connector}\n&/" "${instanceDir}/etc/broker.xml"

connector="<connector name=\"artemis\">tcp:\/\/${BROKER_HOST}:61616<\/connector>"
sed -i "s/<connector name=\"artemis\">.*<\/connector>/${connector}/" "${instanceDir}/etc/broker.xml"

# Remove the acceptors
#sed -i -ne "/<acceptors>/ {p;   " -e ":a; n; /<\/acceptors>/ {p; b}; ba}; p" ${instanceDir}/etc/broker.xml
acceptor="<acceptor name=\"artemis\">tcp:\/\/${BROKER_HOST}:61616?protocols=CORE<\/acceptor>"
sed -i -ne "/<acceptors>/ {p; i $acceptor" -e ":a; n; /<\/acceptors>/ {p; b}; ba}; p" "${instanceDir}/etc/broker.xml"

#start the broker and issue the scaledown command to drain the messages.
"${instanceDir}/bin/artemis-service" start

tail -n 100 -f "${AMQ_NAME}/log/artemis.log" &

waitForJolokia

RET_CODE=$(curl -G -k "http://${AMQ_USER}:${AMQ_PASSWORD}@${BROKER_HOST}:8161/console/jolokia/exec/org.apache.activemq.artemis:broker=%22${AMQ_NAME}%22/scaleDown/scaledownconnector")

EXT_CODE=$?
echo "[drain.sh] curl exit code ${EXT_CODE}"

HTTP_CODE=$(echo "$RET_CODE" | jq -r '.status')

echo "[drain.sh] curl return code ${HTTP_CODE}"

#since Apache Artemis 2.50.0 scaledown causes an empty reply and curl returns with the code 52
if [ "${EXT_CODE}" != "52" ] && [ "${HTTP_CODE}" != "200" ]; then
  echo "[drain.sh] scaleDown is not successful, response: $RET_CODE"
  echo "[drain.sh] sleeping for 30 seconds to allow inspection before it restarts"
  sleep 30
  exit 1
fi

#restart the broker to check messages
"${instanceDir}/bin/artemis-service" stop
if [ $? -ne 0 ]; then
  echo "[drain.sh] force stopping the broker"
  "${instanceDir}/bin/artemis-service" force-stop
fi
"${instanceDir}/bin/artemis-service" start

waitForJolokia

echo "[drain.sh] checking messages are all drained"
RET_VALUE=$(curl -G -k "http://${AMQ_USER}:${AMQ_PASSWORD}@${BROKER_HOST}:8161/console/jolokia/read/org.apache.activemq.artemis:broker=%22${AMQ_NAME}%22/AddressNames")

for address in $(echo ${RET_VALUE} | jq -r '.value[]')
do
  echo "[drain.sh] checking on address ${address}"
  M_COUNT=$(curl -G -k "http://${AMQ_USER}:${AMQ_PASSWORD}@${BROKER_HOST}:8161/console/jolokia/read/org.apache.activemq.artemis:broker=%22${AMQ_NAME}%22,address=%22${address}%22,component=addresses/MessageCount")
  value=$(echo "$M_COUNT" | jq -r '.value')
  if [[ $value -gt 0 ]]; then
    echo "[drain.sh] scaledown not complete. There are $value messages on address $address"
    "${instanceDir}/bin/artemis-service" stop
    exit 1
  fi
done
echo "[drain.sh] scaledown is successful"
"${instanceDir}/bin/artemis-service" stop
if [ $? -ne 0 ]; then
  "${instanceDir}/bin/artemis-service" force-stop
fi
exit 0
