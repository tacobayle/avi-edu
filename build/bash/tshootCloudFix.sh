#!/bin/bash
source /build/avi/avi_api.sh
#
# Removing vCenter content library
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
username='admin'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/cloud"
cloud_response_body=${response_body}
echo ${cloud_response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/vcenterserver"
    vcenterserver_body=${response_body}
    echo ${vcenterserver_body} | jq -c -r .results[] | while read vcenterserver
    do
      echo $(echo ${vcenterserver} | jq -c -r '.cloud_ref')
      if [[ $(basename $(echo ${vcenterserver} | jq -c -r '.cloud_ref')) == ${cloud_uuid} ]] ; then
        json_data=$(echo ${vcenterserver} | jq -c -r '.content_lib += {"id": "'${content_library_uuid}'"}')
        avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/vcenterserver/$(echo ${vcenterserver} | jq -c -r '.uuid')"
      fi
    done
  fi
done