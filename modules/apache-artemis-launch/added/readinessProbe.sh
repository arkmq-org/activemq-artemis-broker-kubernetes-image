#!/usr/bin/env bash

if [ true = "${DEBUG}" ] ; then
  # short circuit readiness check in dev mode
  exit 0
fi

OUTPUT=/tmp/readiness-output
ERROR=/tmp/readiness-error
LOG=/tmp/readiness-log

INSTANCE_DIR="${HOME}/${AMQ_NAME}"
CONFIG_FILE=$INSTANCE_DIR/etc/broker.xml

COUNT=30
SLEEP=1
DEBUG_SCRIPT=true

EVALUATE_SCRIPT=$(cat <<'EOF'
    RESULT=0
    TCP_CON="$(jq --raw-input --slurp 'split("\n") | .[1:-1] | .[] | capture("^ +(?<en>[0-9]+): +(?<la>[0-9A-F]+):(?<lp>[0-9A-F]+) +(?<ra>[0-9A-F]+):(?<rp>[0-9A-F]+) +(?<cs>[0-9A-F]+)")' /proc/net/tcp)"
    TCP_CON="${TCP_CON}$(jq --raw-input --slurp 'split("\n") | .[1:-1] | .[] | capture("^ +(?<en>[0-9]+): +(?<la>[0-9A-F]+):(?<lp>[0-9A-F]+) +(?<ra>[0-9A-F]+):(?<rp>[0-9A-F]+) +(?<cs>[0-9A-F]+)")' /proc/net/tcp6)"

    while IFS= read -r ACCEPTOR_XML; do
        ACCEPTOR_NAME="$(echo "${ACCEPTOR_XML}" | xmlstarlet sel -t -m //_:acceptor/@name -v .)"
        ACCEPTOR_URL="$(echo "${ACCEPTOR_XML}" | xmlstarlet sel -t -m //_:acceptor -v .)"
        echo "${ACCEPTOR_NAME} value ${ACCEPTOR_URL}"

        ACCEPTOR_PORT="$(jq --arg url "${ACCEPTOR_URL}" -n -r '$url | capture("^(?<scheme>[^:]+)://((?<user>[^@]+)@)*(?<host>[^:]+):(?<port>[0-9]+)[?]*").port')"

        if [ -n "${ACCEPTOR_PORT}" ]; then
            LISTENING_TCP_CON="$(echo ${TCP_CON} | jq --arg port "$(printf "%04X" ${ACCEPTOR_PORT})" 'select(.cs == "0A" and .lp == $port)')"

            if [ -n "${LISTENING_TCP_CON}" ]; then
                echo "    Transport is listening on port ${ACCEPTOR_PORT}"
            else
                echo "    Nothing listening on port ${ACCEPTOR_PORT}, transport not yet running"
                RESULT=1
            fi
        else
            echo "    ${ACCEPTOR_NAME} does not define a port, cannot check acceptor"
            RESULT=1
        fi
    done < <(xmlstarlet sel -N c="urn:activemq:core" -t -m "//c:acceptor" -c . -n ${CONFIG_FILE})

    exit ${RESULT}
EOF
)

if [ $# -gt 0 ] ; then
    COUNT=$1
fi

if [ $# -gt 1 ] ; then
    SLEEP=$2
fi

if [ $# -gt 2 ] ; then
    DEBUG_SCRIPT=$3
fi

if [ true = "${DEBUG_SCRIPT}" ] ; then
    echo "Count: ${COUNT}, sleep: ${SLEEP}" > "${LOG}"
fi

while : ; do
    CONNECT_RESULT=1
    PROBE_MESSAGE="No configuration file located: ${CONFIG_FILE}"

    if [ -f "${CONFIG_FILE}" ] ; then
        CONFIG_FILE="${CONFIG_FILE}" bash -c "${EVALUATE_SCRIPT}" >"${OUTPUT}" 2>"${ERROR}"

        CONNECT_RESULT=$?
        if [ true = "${DEBUG_SCRIPT}" ] ; then
            (
                echo "$(date) Connect: ${CONNECT_RESULT}"
                echo "========================= OUTPUT =========================="
                cat "${OUTPUT}"
                echo "========================= ERROR =========================="
                cat "${ERROR}"
                echo "=========================================================="
            ) >> "${LOG}"
        fi

        PROBE_MESSAGE="No transport listening on ports $(grep "Nothing listening" "${OUTPUT}" | sed -e 's+^.*on port ++' -e 's+,.*$++')"
        rm -f  "${OUTPUT}" "${ERROR}"
    fi

    if [ "${CONNECT_RESULT}" -eq 0 ] ; then
        exit 0;
    fi

    COUNT=$((COUNT - 1))
    if [ "$COUNT" -eq 0 ] ; then
        echo "${PROBE_MESSAGE}"
        exit 1;
    fi
    sleep "${SLEEP}"
done
