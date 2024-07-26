#!/bin/bash
#########################################################################
# Audit Azure AD Application Permissions
# This script generates a report of all application permissions in Azure AD.
# It lists the permissions, resource IDs, admin consent status, and expiration dates.
# Usage: ./permission_audit.sh
#########################################################################

# Stop on errors
set -e

# Ensure Azure CLI is logged in
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please login to Azure CLI using 'az login'"
  exit 1
fi

# Get the list of applications
echo "Getting the list of applications..."
apps=$(az ad app list --query "[].{appId:appId,displayName:displayName}" -o tsv)
echo "Found $(echo "$apps" | wc -l) applications."

# Initialize the report file
report_file="app_permissions_report.txt"
echo "Application Permissions Report" > $report_file
echo "=============================" >> $report_file

# Loop through each application
while IFS=$'\t' read -r appId displayName; do
  echo "Processing application: $displayName ($appId)"
  echo "Application: $displayName ($appId)" >> $report_file

  # Get the list of permissions for the application
  permissions=$(az ad app permission list --id $appId | jq -r '.[] | .resourceAppId as $appId | .resourceAccess[] | [$appId, .id, .type] | @tsv')

  if [ -z "$permissions" ]; then
	echo "  No permissions found." >> $report_file
	continue
  fi

  # Loop through each permission
  while IFS=$'\t' read -r resourceId scopeId accesType ; do

	# Check if admin consent is required
	# adminConsent=$(az ad app permission admin-consent --id $appId --query "[?resourceId=='$resourceId' && scope=='$scope'].{adminConsent:adminConsent}" -o tsv)

	# Get the expiration date (if any)
	expiration=$(az ad app permission list --id $appId --query "[?resourceId=='$resourceId' && scope=='$scope'].{expiryTime:expiryTime}" -o tsv)

	# Append to the report
	echo "  Permission: $scope" >> $report_file
	echo "    Resource ID: $resourceId" >> $report_file
	echo "    Admin Consent Required: $adminConsent" >> $report_file
	echo "    Expiration: ${expiration:-'N/A'}" >> $report_file
  done <<< "$permissions"

  echo "" >> $report_file
done <<< "$apps"

echo "Report generated: $report_file"