#!/usr/bin/env bash
#Script to run snyk-cli and check for package vulnerabilities
#version 0.2

PRODUCT=$1
EXPOSURE=$2
BUILD_SYSTEM=$3
GROUP=$4
source ww.metadata
GIT_SHA=$(git rev-parse --short HEAD)

function installsnyk () {
	#Install Snyk 
	npm install -g snyk
	if [ $? -eq 0 ]; then
		echo "Snyk Installed Successfully"
	else
		echo "Snyk Install Failed"
		exit 1
	fi
}

function snyk_verification () {	
	#Snyk Test against built image
    echo "Scanning artifact for vulnerabilities"
    snyk test --severity-threshold=high --org=weight-watchers-org --json >> snyk_report.json
    sleep 10
    cat snyk_report.json
	sleep 5
    BUILD_SCORE=$( cat snyk_report.json | jq -r '.uniqueCount')
    echo "Build Score: $BUILD_SCORE"
}

#Function that will create the deployment 
function pushlogs() {
    echo "Pushing Logs to Logger API"
    curl -X POST -d"{"uniqueCount": $BUILD_SCORE}" https://parc-logger-api.prod.ops.us-east-1.aws.wwiops.io/logs/build/$EXPOSURE/$sec_critical_system/$sec_owner/$sec_repository/$PRODUCT/$GIT_SHA
    curl -X POST -d@snyk_report.json https://parc-logger-api.prod.ops.us-east-1.aws.wwiops.io/logs/build/$EXPOSURE/$sec_critical_system/$sec_owner/$sec_repository/$PRODUCT/$GIT_SHA
}

#Function to push build metadata to IDB
function pushtoIDB() {
    echo ""
    echo "Pushing Build Metadata to IDB"
    git clone https://$GITHUB_PERSONAL_ACCESS_TOKEN@github.com/WW-Digital/trigger-oidc-curl
    $CIRCLE_WORKING_DIRECTORY/trigger-oidc-curl/bin/trigger-oidc-curl --profile=google_v4_svc --serviceaccount=$TRIGGER_OIDC_CURL_SERVICE_ACCOUNT -XPOST -d"{\"exposure\": \"$EXPOSURE\", \"critical\": \"$sec_critical_system\", \"owner\": \"$sec_owner\", \"repository\": \"$sec_repository\", \"buildid\": \"$CIRCLE_BUILD_URL\", \"buildsha\": \"$GIT_SHA\", \"buildscore\": $BUILD_SCORE, \"buildsystem\": \"$BUILD_SYSTEM\", \"group\": \"$GROUP\"}" https://circle-proxy.prod.ops.us-east-1.aws.wwiops.io/builds
    if [ $? -eq 0 ]; then
        echo "Image Build Successful"
    else
        echo "Image Build Failed"
        exit 1
    fi
}

installsnyk
snyk_verification
pushlogs
pushtoIDB

echo ""
echo ""
echo "Build Completed"
echo ""
echo ""
