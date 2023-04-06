#!/bin/bash
set -x

SLEEP_AT_WORK_SECS=5
LOG_COUNT=1

HOME_TENANT_ID=$(az account show --query homeTenantId -o tsv)
APP_CLIENT_ID="50606203bc"
APP_CLIENT_SECRET="x.J8Q~gc83"

RESP=$(curl -X POST "https://login.microsoftonline.com/${HOME_TENANT_ID}/oauth2/token" \
-H "Content-Type: application/x-www-form-urlencoded" \
--data-urlencode "grant_type=client_credentials" \
--data-urlencode "client_id=${APP_CLIENT_ID}" \
--data-urlencode "client_secret=${APP_CLIENT_SECRET}" \
--data-urlencode "resource=https://monitor.azure.com")

ACCESS_TOKEN=$(echo $RESP | jq -r '.access_token')
echo $ACCESS_TOKEN
VM_RES_ID="subscriptions/1e3/resourceGroups/Miztiik_Enterprises_custom_metrics_to_azure_monitor_002/providers/Microsoft.Compute/virtualMachines/m-web-srv-002"
# VM_RES_ID=$(curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/compute/resourceId?api-version=2021-05-01&format=text")
ACCESS_TOKEN1="eyJ0eXAiOrWCAtgHzh6Jf0vTFA"


for ((i=1; i<=LOG_COUNT; i++)); do

    # Set variable values
    CURR_TIME=$(date +"%Y-%m-%dT%H:%M:%S")
    TIME_TWO_HRS_AGO=$(date -d "-2 hours" +"%Y-%m-%dT%H:%M:%S") 
    METRIC="QueueDepth"
    NAMESPACE="QueueProcessing"
    QUEUE_NAME="ImagesToProcess"
    MESSAGE_TYPE="JPEG"
    MIN=$(shuf -i 1-10 -n 1)
    MAX=$(shuf -i 11-20 -n 1)
    SUM=$(shuf -i 21-30 -n 1)
    COUNT=$(shuf -i 1-5 -n 1)

    # Build JSON string
    JSON_DATA="{\"time\":\"$CURR_TIME\",\"data\":{\"baseData\":{\"metric\":\"$METRIC\",\"namespace\":\"$NAMESPACE\",\"dimNames\":[\"QueueName\",\"MessageType\"],\"series\":[{\"dimValues\":[\"$QUEUE_NAME\",\"$MESSAGE_TYPE\"],\"min\":$MIN,\"max\":$MAX,\"sum\":$SUM,\"count\":$COUNT}]}}}"

    echo "$JSON_DATA"

    curl --write-out %{http_code} -X POST "https://westeurope.monitoring.azure.com/${VM_RES_ID}/metrics" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$JSON_DATA"

    sleep $SLEEP_AT_WORK_SECS
done
