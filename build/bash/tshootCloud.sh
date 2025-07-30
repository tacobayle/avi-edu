#!/bin/bash
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
# Reapplying Cloud NSX config
#
fqdn=sa-avicon-01.vclass.local
username='admin'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  echo $(echo ${item} | jq -c -r '.vtype')
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    govc library.rm SA-NSX
    avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "$(echo ${item} | jq -c -r '.')" "${fqdn}" "api/cloud/$(echo ${item} | jq -c -r '.uuid')"
  fi
done
#
# Creating API session
#
fqdn=sa-avicon-01.vclass.local
username='admin'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
# retrieve nsx cloud url and cloud uuid
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  echo $(echo ${item} | jq -c -r '.vtype')
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/vrfcontext"
    echo ${response_body} | jq -c -r .results[] | while read vrf
    do
      if [[ $(echo ${vrf} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vrf} | jq -c -r '.name') == "SA-T1" ]]; then
        vrf_uuid=$(echo ${vrf} | jq -c -r '.uuid')
        json_data=$(echo ${vrf} | jq -c -r 'del(.static_routes)')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/vrfcontext/${vrf_uuid}"
      fi
    done
  fi
done
