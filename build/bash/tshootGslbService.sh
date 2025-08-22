#!/bin/bash
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
# Site A
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cluster"
cluster_uuid_a=$(echo $response_body | jq -c -r --arg tenant "${tenant}" '.uuid')
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/gslbservice"
echo ${response_body} | jq -c -r .results[] | while read vs
do
  if [[ $(echo ${vs} | jq -c -r '.name') == "tshoot" ]]; then
    gslb_uuid=$(echo ${vs} | jq -c -r '.uuid')
    avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/gslbservice/${gslb_uuid}"
  fi
done
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "vs-a" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        vsvip_api_path=$(echo ${vs} | jq -c -r '.vsvip_ref' | cut -d/ -f4-)
        pool_api_path=$(echo ${vs} | jq -c -r '.pool_ref' | cut -d/ -f4-)
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "${vsvip_api_path}"
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "${pool_api_path}"
      fi
    done
    #
    # Recreating vs-a-vip
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "vs-a.sa.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "vs-a-VsVip",
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
    vsvip_ip=$(echo $response_body | jq -c -r .vip[0].ip_address.addr)
    #
    # Recreating pool for vs-a
    #
    json_data='
    {
      "cloud_ref": "https://sa-avicon-01.vclass.local/api/cloud/'${nsx_cloud_uuid}'",
      "default_server_port": 30001,
      "enabled": true,
      "name": "vs-a-pool",
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
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
    pool_url=$(echo ${response_body} | jq -c -r '.url')
    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "/api/cloud/'${nsx_cloud_uuid}'",
      "name": "vs-a",
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
    vs_uuid=$(echo ${response_body} | jq -c -r '.uuid')
    gslb_details=$(echo "[]" | jq '. += [{"cluster_uuid": "'${cluster_uuid_a}'", "vs_uuid": "'${vs_uuid}'", "vsvip_ip": "'${vsvip_ip}'", "primary": true, "priority": 20}]')
    echo ${gslb_details} | jq . | tee /tmp/gslb.json
  fi
done
fqdn=sb-avicon-01.vclass.local
username='avi-edu'
password='VMware1!'
avi_version='31.1.1'
avi_cookie_file="/tmp/$(basename $0 | cut -d"." -f1)_${date_index}_cookie.txt"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${username}\", \"password\": \"${password}\"}" \
                                -c ${avi_cookie_file} https://${fqdn}/login)
csrftoken=$(cat ${avi_cookie_file} | grep csrftoken | awk '{print $7}')
#
# Site B
#
avi_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cluster"
cluster_uuid_b=$(echo $response_body | jq -c -r --arg tenant "${tenant}" '.uuid')
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice"
    echo ${response_body} | jq -c -r .results[] | while read vs
    do
      if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.name') == "vs-b" ]]; then
        vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
        vsvip_api_path=$(echo ${vs} | jq -c -r '.vsvip_ref' | cut -d/ -f4-)
        pool_api_path=$(echo ${vs} | jq -c -r '.pool_ref' | cut -d/ -f4-)
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "${vsvip_api_path}"
        avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "${pool_api_path}"
      fi
    done
    #
    # Recreating vs-b-vs-vip
    #
    json_data='
    {
      "cloud_ref": "'${nsx_cloud_url}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "vs-b.sb.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "vs-b-VsVip",
      "vip": [
        {
          "auto_allocate_ip": true,
          "ipam_network_subnet": {
            "network_ref": "/api/network/?name=NSX-SB-VIP",
            "subnet": {
              "ip_addr": {
                "addr": "192.168.141.0",
                "type": "V4"
              },
              "mask": 24
            }
          },
          "placement_networks": [
            {
              "network_ref": "/api/network/?name=NSX-SB-VIP",
              "subnet": {
                "ip_addr": {
                  "addr": "192.168.141.0",
                  "type": "V4"
                },
                "mask": 24
              }
            }
          ]
        }
      ],
      "vrf_context_ref": "/api/vrfcontext/?name=global"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/vsvip"
    vsvip_url=$(echo ${response_body} | jq -c -r '.url')
    vsvip_ip=$(echo $response_body | jq -c -r .vip[0].ip_address.addr)
    #
    # Recreating pool for vs-b
    #
    json_data='
    {
      "cloud_ref": "/api/cloud/'${nsx_cloud_uuid}'",
      "default_server_port": 30001,
      "enabled": true,
      "name": "vs-b-pool",
      "health_monitor_refs": ["/api/healthmonitor?name=System-HTTP"],
      "servers": [
        {
          "enabled": true,
          "hostname": "sb-server-01",
          "ip": {
            "addr": "192.168.131.10",
            "type": "V4"
          }
        },
        {
          "enabled": true,
          "hostname": "sb-server-02",
          "ip": {
            "addr": "192.168.131.11",
            "type": "V4"
          }
        }
      ],
      "placement_networks": [
        {
          "network_ref": "/api/network/?name=NSX-SB-WEB",
          "subnet": {
            "ip_addr": {
              "addr": "192.168.131.0",
              "type": "V4"
            },
            "mask": 24
          }
        }
      ],
      "vrf_ref": "/api/vrfcontext/?name=global"
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/pool"
    pool_url=$(echo ${response_body} | jq -c -r '.url')    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "'${nsx_cloud_url}'",
      "name": "vs-b",
      "vsvip_ref": "'${vsvip_url}'",
      "pool_ref": "'${pool_url}'",
      "enabled": false,
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
    vs_uuid=$(echo ${response_body} | jq -c -r '.uuid')
    gslb_details=$(jq -c -r '.' /tmp/gslb.json)
    rm /tmp/gslb.json
    gslb_details=$(echo $gslb_details | jq '. += [{"cluster_uuid": "'${cluster_uuid_b}'", "vs_uuid": "'${vs_uuid}'", "vsvip_ip": "'${vsvip_ip}'", "primary": false, "priority": 10}]')
    echo ${gslb_details} | jq . | tee /tmp/gslb.json
  fi
done
#
# Site A
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
# disaster-recovery use case
#
groups_json="[]"
pool_count=1
gslb_details=$(jq -c -r '.' /tmp/gslb.json)
for item in $(echo $gslb_details | jq -c -r .[])
do
  groups_json=$(echo $groups_json | jq '. += [{"name": "pool-'${pool_count}'", "priority": "'$(echo $item | jq -c -r .priority)'", "members": [{"cluster_uuid": "'$(echo $item | jq -c -r .cluster_uuid)'", "vs_uuid": "'$(echo $item | jq -c -r .vs_uuid)'", "ip": {"addr": "'$(echo $item | jq -c -r .vsvip_ip)'", "type": "V4"}}]}]')
  ((pool_count++))
done
json_data='
{
  "name": "tshoot",
  "ttl": 0,
  "domain_names": ["tshoot.gslb.vclass.local"],
  "pool_algorithm": "GSLB_SERVICE_ALGORITHM_PRIORITY",
  "groups": '${groups_json}'
}'
avi_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/gslbservice"