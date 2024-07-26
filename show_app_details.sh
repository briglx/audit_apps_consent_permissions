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


# Loop through each application
while IFS=$'\t' read -r appId displayName; do
    echo "Application: $displayName ($appId)"

    # Get the app details
    app=$(az ad app show --id "$appId")
    
    # Get the .api.oauth2PermissionScopes
    oauth2PermissionScopes=$(echo "$app" | jq -r '.api.oauth2PermissionScopes[] | [.id, .value, .userConsentDisplayName] | @tsv')

    if [ -n "$oauth2PermissionScopes" ]; then
        
        # Print the oauth2PermissionScopes
        while IFS=$'\t' read -r permissionId permissionValue userConsentDisplayName; do
            echo "    oauth2PermissionScope: $permissionId $permissionValue $userConsentDisplayName"
        done <<< "$oauth2PermissionScopes"
    fi

    # Get the requiredResourceAccess
    requiredResourceAccess=$(echo "$app" | jq -r '.requiredResourceAccess[] | .resourceAppId as $appId | .resourceAccess[] | [$appId, .id, .type] | @tsv')

    # check if requiredResourceAccess is empty
    if  [ -n "$requiredResourceAccess" ]; then
        
        while IFS=$'\t' read -r resourceId scopeId accesType ; do
            echo "    requiredResourceAccess: $resourceId $scopeId $accesType"
        done <<< "$requiredResourceAccess"
    fi

    # Get admin consent
    adminConsent=$(az ad app permission list-grants --id "$appId" --query "[].{consentType:consentType,principalId:principalId,resourceId:resourceId,scope:scope,startTime:startTime,endTime:endTime}" -o tsv)
    
    # Print the adminConsent
    if [ -n "$adminConsent" ]; then
        while IFS=$'\t' read -r consentType principalId resourceId scope startTime endTime; do
            echo "    adminConsent: $consentType $principalId $resourceId $scope $startTime $endTime"
        done <<< "$adminConsent"
    fi

    # Print the requiredResourceAccess
    
  
done <<< "$apps"