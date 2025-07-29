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
    # Removing VS of cloud NSX-T to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "webapp-header" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
      fi
    done
    #
    # Removing vsvip of cloud NSX-T to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/vsvip"
    echo ${response_body} | jq -c -r .results[] | while read vsvip
    do
      if [[ $(echo ${vsvip} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vsvip} | jq -c -r '.name') == "webapp-header-VsVip" ]]; then
        vsvip_uuid=$(echo ${vsvip} | jq -c -r '.uuid')
	      avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/vsvip/${vsvip_uuid}"
      fi
    done
    #
    # Removing pool of cloud NSX-T to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/pool"
    echo ${response_body} | jq -c -r .results[] | while read pool
    do
      if [[ $(echo ${pool} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${pool} | jq -c -r '.name') == "webapp-header-pool" ]]; then
        pool_uuid=$(echo ${pool} | jq -c -r '.uuid')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/pool/${pool_uuid}"
      fi
    done
    #
    # Removing application profile to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/applicationprofile"
    echo ${response_body} | jq -c -r .results[] | while read ap
    do
      if [[ $(echo ${ap} | jq -c -r '.name') == "webapp-header-application-profile" ]]; then
        ap_uuid=$(echo ${ap} | jq -c -r '.uuid')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/applicationprofile/${ap_uuid}"
      fi
    done
    #
    # Removing http policy set to avoid name conflict
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/httppolicyset"
    echo ${response_body} | jq -c -r .results[] | while read http_set
    do
      if [[ $(echo ${http_set} | jq -c -r '.name') == "webapp-header-policy" ]]; then
        http_set_uuid=$(echo ${http_set} | jq -c -r '.uuid')
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "" "${fqdn}" "api/httppolicyset/${http_set_uuid}"
      fi
    done
    #
    # Recreating webapp-header vs-vip
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "webapp-header.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "webapp-header-VsVip",
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
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
    vsvip_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating pool for webapp-header-pool
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "default_server_port": 30001,
      "enabled": true,
      "name": "webapp-header-pool",
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
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
    pool_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Create application profile
    #
    json_data='
    {
      "type": "APPLICATION_PROFILE_TYPE_HTTP",
      "http_profile": {
        "xff_enabled": true,
        "http_to_https": false,
        "client_max_header_size": 12,
        "client_max_request_size": 48,
        "xff_alternate_name": "X-Forwarded-For"
      },
      "name": "webapp-header-application-profile"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/applicationprofile"
    applicationprofile_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Create http policy
    #
    json_data='
    {
      "http_request_policy": {
        "rules": [
          {
            "index": 1,
            "enable": true,
            "name": "Insert-Custom-XFF",
            "match": {
              "client_ip": {
                "group_refs": [
                  "/api/ipaddrgroup?name=Internal"
                ],
                "match_criteria": "IS_IN"
              }
            },
            "hdr_action": [
              {
                "action": "HTTP_ADD_HDR",
                "hdr": {
                  "name": "X-Forwarded-For",
                  "value": {
                    "val": "InternalSubnet"
                  }
                }
              }
            ]
          }
        ]
      },
      "is_internal_policy": false,
      "name": "webapp-header-policy"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/httppolicyset"
    httppolicyset_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "name": "webapp-header",
      "vsvip_ref": "'${vsvip_url}'",
      "pool_ref": "'${pool_url}'",
      "http_policies": [
          {
            "index": 11,
            "http_policy_set_ref": "'${httppolicyset_url}'"
          }
      ],
      "application_profile_ref": "'${applicationprofile_url}'",
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
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "${username}" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
  fi
done
