#!/bin/bash
/bin/bash /build/bash/initializeYourVs.sh
source /build/avi/avi_api.sh
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
#
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    # update seg to 20 vs
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup"
    echo ${response_body} | jq -c -r .results[] | while read seg
    do
      serviceneginegroup_uuid=$(echo ${seg} | jq -c -r '.uuid')
      if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${seg} | jq -c -r '.name') == "Default-Group" ]]; then
        json_data=$(echo ${seg} | jq -c -r '.+={"max_vs_per_se": 20}')
	      avi_api 2 2 "PUT" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/serviceenginegroup/${serviceneginegroup_uuid}"
      fi
    done
    for i in {1..2}; do
      prefix="blue"
      #
      # Recreating nsx-overlay-vs-vip
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "dns_info": [
          {
            "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
            "fqdn": "'${prefix}'-'${i}'.sa.vclass.local",
            "ttl": 30,
            "type": "DNS_RECORD_A"
          }
        ],
        "name": "'${prefix}'-vs-VsVip-'${i}'",
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
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
      vsvip_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating pool for nsx-overlay-vs
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "default_server_port": 30001,
        "enabled": true,
        "name": "'${prefix}'-vs-pool-'${i}'",
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
        "vrf_ref": "/api/vrfcontext/?name=SA-T1",
        "markers":[{"key":"team","values":["'${prefix}'"]}]
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
      pool_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating the VS
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "name": "'${prefix}'-vs-'${i}'",
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
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
    done
    for i in {1..2}; do
      prefix="green"
      #
      # Recreating nsx-overlay-vs-vip
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "dns_info": [
          {
            "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
            "fqdn": "'${prefix}'-'${i}'.sa.vclass.local",
            "ttl": 30,
            "type": "DNS_RECORD_A"
          }
        ],
        "name": "'${prefix}'-vs-VsVip-'${i}'",
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
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
      vsvip_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating pool for nsx-overlay-vs
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "default_server_port": 30001,
        "enabled": true,
        "name": "'${prefix}'-vs-pool-'${i}'",
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
        "vrf_ref": "/api/vrfcontext/?name=SA-T1",
        "markers":[{"key":"team","values":["'${prefix}'"]}]
      }'
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
      pool_url=$(echo ${response_body} | jq -c -r '.url')
      #
      # Recreating the VS
      #
      json_data='
      {
        "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
        "name": "'${prefix}'-vs-'${i}'",
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
      avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
    done
    json_data='
    {
      "allow_unlabelled_access":false,
      "filters":
      [
        {
          "enabled":true,
          "match_label": {"key":"team","values":["blue"]},
          "match_operation":"ROLE_FILTER_EQUALS"
        }
      ],
      "name":"role-blue",
      "privileges":
      [
        {
          "resource":"PERMISSION_VIRTUALSERVICE",
          "type":"WRITE_ACCESS"
        },
        {
          "resource":"PERMISSION_POOL",
          "type":"WRITE_ACCESS"
        },
        {
          "resource":"PERMISSION_POOLGROUP",
          "type":"WRITE_ACCESS"
        }
      ]
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/role"
    json_data='
    {
      "allow_unlabelled_access":false,
      "filters":
      [
        {
          "enabled":true,
          "match_label": {"key":"team","values":["green"]},
          "match_operation":"ROLE_FILTER_EQUALS"
        }
      ],
      "name":"role-green",
      "privileges":
      [
        {
          "resource":"PERMISSION_VIRTUALSERVICE",
          "type":"WRITE_ACCESS"
        },
        {
          "resource":"PERMISSION_POOL",
          "type":"WRITE_ACCESS"
        },
        {
          "resource":"PERMISSION_POOLGROUP",
          "type":"WRITE_ACCESS"
        }
      ]
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/role"
    json_data='
    {
      "password": "VMware1!",
      "username": "blue",
      "name": "blue",
      "full_name": "blue",
      "email": "blue@vmware.com",
      "is_superuser": false,
      "is_active": true,
      "default_tenant_ref": "/api/tenant/?name=admin",
      "user_profile_ref": "/api/useraccountprofile/?name=Default-User-Account-Profile"
    }'
    avi_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/user"
    json_data='
    {
      "password": "VMware1!",
      "username": "green",
      "name": "green",
      "full_name": "green",
      "email": "green@vmware.com",
      "is_superuser": false,
      "is_active": true,
      "default_tenant_ref": "/api/tenant/?name=admin",
      "user_profile_ref": "/api/useraccountprofile/?name=Default-User-Account-Profile"
    }'
    avi_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/user"
  fi
done