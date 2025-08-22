#!/bin/bash
source /build/avi/avi_api.sh
#
# patching the VRF route
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
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  echo $(echo ${item} | jq -c -r '.vtype')
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/vrfcontext"
    echo ${response_body} | jq -c -r .results[] | while read vrf
    do
      if [[ $(echo ${vrf} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vrf} | jq -c -r '.name') == "SA-T1" ]]; then
        vrf_uuid=$(echo ${vrf} | jq -c -r '.uuid')
        json_data=$(echo ${vrf} | jq -c -r '. += {"static_routes": [{"next_hop": {"addr": "22.0.0.1", "type": "V4"}, "prefix": {"ip_addr" :{"addr": "0.0.0.0", "type": "V4"}, "mask": 0}, "route_id": "1"}]}')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vrfcontext/${vrf_uuid}"
      fi
    done
  fi
done

#
# Adding vCenter content library
#
rm -f /tmp/cm
export GOVC_USERNAME='administrator@vsphere.local'
export GOVC_PASSWORD='VMware1!'
export GOVC_DATACENTER='SiteA-Production'
export GOVC_INSECURE=true
export GOVC_DATASTORE='SA-Shared-02-Remote'
export GOVC_URL='sa-vcsa-01.vclass.local'
export GOVC_CLUSTER='[SiteA-Edge-Cluster-01]'
govc library.ls -json | jq -c -r '.[]' | while read cm
do
   if [[ $(echo ${cm} | jq -c -r '.name') == "SA-NSX" ]]; then
     touch /tmp/cm
   fi
done
if [ -f "/tmp/cm" ]; then
  exit
fi
content_library_uuid=$(govc library.create SA-NSX)
#
# patching vcenterserver
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
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
cloud_response_body=${response_body}
echo ${cloud_response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/vcenterserver"
    vcenterserver_body=${response_body}
    echo ${vcenterserver_body} | jq -c -r .results[] | while read vcenterserver
    do
      echo $(echo ${vcenterserver} | jq -c -r '.cloud_ref')
      if [[ $(basename $(echo ${vcenterserver} | jq -c -r '.cloud_ref')) == ${cloud_uuid} ]] ; then
        json_data=$(echo ${vcenterserver} | jq -c -r '.content_lib += {"id": "'${content_library_uuid}'"}')
        avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vcenterserver/$(echo ${vcenterserver} | jq -c -r '.uuid')"
      fi
    done
  fi
done
#
# retrieve nsx cloud url and cloud uuid and update the VRF route
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  echo $(echo ${item} | jq -c -r '.vtype')
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/vrfcontext"
    echo ${response_body} | jq -c -r .results[] | while read vrf
    do
      if [[ $(echo ${vrf} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vrf} | jq -c -r '.name') == "SA-T1" ]]; then
        vrf_uuid=$(echo ${vrf} | jq -c -r '.uuid')
        json_data=$(echo ${vrf} | jq -c -r '. += {"static_routes": [{"next_hop": {"addr": "22.0.0.1", "type": "V4"}, "prefix": {"ip_addr" :{"addr": "0.0.0.0", "type": "V4"}, "mask": 0}, "route_id": "1"}]}')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vrfcontext/${vrf_uuid}"
      fi
    done
  fi
done