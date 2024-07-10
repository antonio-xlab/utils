#!/bin/bash

#
# Script that publishes an app deployment event to an Azure Application Insights workspace.
# Can be used in tandem with Octopus pipelines such that events are published when new code is deployed.
#
# USAGE
# Format: sh publish_event_to_azappi.sh <I_KEY> <OWNER> <APP_NAME> <TENANT> <ENVIRONMENT> <DEPLOYMENT_STATUS>
#
# Examples: 
#			sh publish_event_to_azappi.sh "InstrumentationKey" "Antonio" "Gateway" "GBR" "Staging" "Success"
#

azure_appi_endpoint="https://dc.services.visualstudio.com/v2/track"
event_name="App Deployment Event"

# INPUTS
instrumentation_key=$1        
owner=$2                    # who ran the deployment
app_name=$3                 # the name of the app / service that was deployed
tenant=$4                   # the tenant in which the deployment took place (e.g GBR, AUS, etc.)
environment=$5              # the environment in which the deployment took place (e.g Staging)
deploymentStatus=$6         # the status of the deployment (e.g success / fail)

# ARG VALIDATION
if [[ $# -lt 6 ]]; then
	echo "Example usage:"
	echo "  sh publish_event_to_azappi.sh \"InstrumentationKey\" \"Antonio\" \"Gateway\" \"GBR\" \"Staging\" \"Success\""
	exit 1
fi

now=$(date +%Y-%m-%dT%H:%M:%S%z) # current timestamp in ISO-8601 format to please the Azure overlords

# Build the custom event JSON object from the given parameters
json_data=$(cat <<EOF
[{
   "name": "Microsoft.ApplicationInsights.Event",
   "time": "$now",
   "iKey": "$instrumentation_key",
   "tags": {},
   "data": {
      "baseType": "EventData",
      "baseData": {
         "ver": 2,
         "name": "$event_name",
         "properties": {
            "Owner": "$owner",
            "AppName": "$app_name",
            "Tenant": "$tenant",
            "Environment": "$environment",
            "DeploymentStatus": "$deploymentStatus"
         }
      }
   }
}]
EOF
)

# Send the HTTP request to Azure
curl --location $azure_appi_endpoint \
--header 'Content-Type: text/plain' \
--data "$json_data"