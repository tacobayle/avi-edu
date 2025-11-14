#!/bin/bash
/bin/bash /build/bash/initializeYourVs.sh
source /build/avi/avi_api.sh
#
# Removing vCenter content library
#
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware1!'
export GOVC_DATACENTER='SiteA-Production'
export GOVC_INSECURE=true
export GOVC_URL='sa-vcsa-01.vclass.local'
export GOVC_CLUSTER='[SiteA-Edge-Cluster-01]'
#
# Creating API session
#
fqdn=sa-avicon-01.vclass.local
username='avi-edu'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
# creating username vmware
#
json_data='
{
  "access": [
    {
      "role_ref": "/api/role/?name=Application-Operator",
      "tenant_ref": "/api/tenant/?name=admin",
      "all_tenants": false
    }
  ],
  "password": "VMware1!",
  "username": "vmware",
  "name": "vmware",
  "full_name": "vmware",
  "email": "vmware@vmware.com",
  "is_superuser": false,
  "is_active": true,
  "default_tenant_ref": "/api/tenant/?name=admin",
  "user_profile_ref": "/api/useraccountprofile/?name=Default-User-Account-Profile"
}'
avi_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/user"
#
