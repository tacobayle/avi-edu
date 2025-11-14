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
# get tenants
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/tenant?page_size=-1"
tenant_results=$(echo $response_body | jq -c -r '.results')
#
# delete tenants
#
#echo ${tenant_results} | jq -c -r '.[]' | while read tenant
#do
#  tenant_name=$(echo ${tenant} | jq -c -r '.name')
#  tenant_url=$(echo ${tenant} | jq -c -r '.url')
#  if [[ ${tenant_name} != "admin" ]] ; then
#    avi_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "$(echo ${tenant_url} | grep / | cut -d/ -f4-)"
#  fi
#done
#
# create tenants
#
if [[ $(echo ${tenant_results} | jq -c -r '.[] | select(.name == "dev-tenant").name') != "dev-tenant" ]]; then
  json_data='
  {
    "name": "dev-tenant",
    "config_settings": {
      "tenant_vrf": false,
      "se_in_provider_context": true,
      "tenant_access_to_provider_se": true
    }
  }'
  avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/tenant"
fi
#
#
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    # Recreating nsx-overlay-vs-vip in tenant01
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "dev-vs.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "dev-vs",
      "vip": [
        {
          "auto_allocate_ip": true,
          "ipam_network_subnet": {
            "network_ref": "/api/network/?name=SA-Overlay-VIP",
            "subnet": {
              "ip_addr": {
                "addr": "22.0.0.0",
                "type": "V4"
              },
              "mask": 24
            }
          }
	      }
      ],
      "vrf_context_ref": "/api/vrfcontext/?name=SA-T1"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "dev-tenant" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
    vsvip_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating pool for nsx-overlay-vs
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "default_server_port": 30001,
      "enabled": true,
      "name": "dev-vs-pool",
      "health_monitor_refs": ["/api/healthmonitor?name=System-HTTP"],
      "servers": [
        {
          "enabled": true,
          "hostname": "sa-server-01",
          "ip": {
            "addr": "192.168.130.10",
            "type": "V4"
          }
        },
        {
          "enabled": true,
          "hostname": "sa-server-02",
          "ip": {
            "addr": "192.168.130.11",
            "type": "V4"
          }
        },
        {
          "enabled": true,
          "hostname": "sa-server-03",
          "ip": {
            "addr": "192.168.130.12",
            "type": "V4"
          }
        }
      ],
      "vrf_ref": "/api/vrfcontext/?name=SA-T1"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "dev-tenant" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
    pool_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "name": "dev-vs",
      "vsvip_ref": "'${vsvip_url}'",
      "pool_ref": "'${pool_url}'",
      "analytics_policy": {
        "udf_log_throttle": 10,
        "full_client_logs": {
          "duration": 0,
          "throttle": 10,
          "enabled": true
        },
        "metrics_realtime_update": {
          "duration": 0,
          "enabled": true
        },
        "significant_log_throttle": 10,
        "client_insights": "NO_INSIGHTS",
        "all_headers": true
      },
      "services": [{"port": 80, "enable_ssl": false}, {"port": 443, "enable_ssl": true}]
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "dev-tenant" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
  fi
done
