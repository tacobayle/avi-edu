#!/bin/bash
source /build/avi/avi_api.sh
#
# Creating API session
#
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
# update nsx cloud
#
avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/cloud"
echo ${response_body} | jq -c -r .results[] | while read item
do
  if [[ $(echo ${item} | jq -c -r '.vtype') == "CLOUD_NSXT" ]]; then
    nsx_cloud_uuid=$(echo ${item} | jq -c -r '.uuid')
    nsx_cloud_url=$(echo ${item} | jq -c -r '.url')
    #
    # Remove and Create SEG for GSLB
    #
    avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup"
    echo ${response_body} | jq -c -r .results[] | while read seg
    do
      if [[ $(echo ${seg} | jq -c -r '.name') == "gslb01" ]]; then
        serviceneginegroup_url=$(echo ${seg} | jq -c -r '.url')
        serviceneginegroup_uuid=$(echo ${seg} | jq -c -r '.uuid')
        avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice"
        echo ${response_body} | jq -c -r .results[] | while read vs
        do
          if [[ $(echo ${vs} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${vs} | jq -c -r '.se_group_ref') == "${serviceneginegroup_url}" ]]; then
            vs_uuid=$(echo ${vs} | jq -c -r '.uuid')
            vsvip_api_path=$(echo ${vs} | jq -c -r '.vsvip_ref' | cut -d/ -f4-)
            echo ${vsvip_api_path}
            avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/virtualservice/${vs_uuid}"
            avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "${vsvip_api_path}"
          fi
        done
        avi_api 2 2 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceengine-inventory/?se_group_ref.uuid=${serviceneginegroup_uuid}"
        echo ${response_body} | jq -c -r .results[] | while read se
        do
          if [[ $(echo ${se} | jq -c -r '.config.virtualservice_refs | length') ==  0 ]]; then
            se_uuid=$(echo ${se} | jq -c -r '.config.uuid')
            avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceengine/${se_uuid}"
          fi
        done
        if [[ $(echo ${seg} | jq -c -r '.cloud_ref') == ${nsx_cloud_url} && $(echo ${seg} | jq -c -r '.name') == "gslb01" ]]; then
          avi_api 2 2 "DELETE" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "" "${fqdn}" "api/serviceenginegroup/${serviceneginegroup_uuid}"
        fi
      fi
    done
    #
    # Create SEG for GSLB
    #
    json_data='
    {
      "ha_mode": "HA_MODE_SHARED",
      "max_se": 1,
      "cloud_ref": "'${nsx_cloud_url}'",
      "algo": "PLACEMENT_ALGO_PACKED",
      "buffer_se": 0,
      "name": "gslb01",
      "max_vs_per_se": 1,
      "min_scaleout_per_vs": 1,
      "max_scaleout_per_vs": 1,
      "se_name_prefix": "sbgslb01",
      "cpu_reserve": false,
      "mem_reserve": false,
      "memory_per_se": 8192,
      "disk_per_se": 40,
      "extra_shared_config_memory": 2000,
      "vcpus_per_se": 1
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/serviceenginegroup"
    #
    #
    #
    json_data='
    {
      "cloud_ref": "'${nsx_cloud_url}'",
      "dns_info": [
        {
          "algorithm": "DNS_RECORD_RESPONSE_CONSISTENT_HASH",
          "fqdn": "sb-global-dns-01.sb.vclass.local",
          "ttl": 30,
          "type": "DNS_RECORD_A"
        }
      ],
      "name": "sb-global-dns-01-VsVip",
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
    #
    # Recreating the VS
    #
    json_data='
    {
      "cloud_ref": "'${nsx_cloud_url}'",
      "name": "sb-global-dns-01",
      "vsvip_ref": "'${vsvip_url}'",
      "application_profile_ref": "/api/applicationprofile/?name=System-DNS",
      "network_profile_ref": "/api/networkprofile/?name=System-UDP-Per-Pkt",
      "se_group_ref": "/api/serviceenginegroup/?name=gslb01",
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
      "services": [{"port": 53, "enable_ssl": false}, {"port": 53, "enable_ssl": false, "override_network_profile_ref": "/api/networkprofile/?name=System-TCP-Proxy"}]
    }'
    avi_api 2 2 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${avi_version}" "${json_data}" "${fqdn}" "api/virtualservice"
  fi
done
