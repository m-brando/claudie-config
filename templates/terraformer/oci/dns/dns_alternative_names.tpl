{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID 	       := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

{{- if hasExtension .Data "AlternativeNamesExtension" }}
	{{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}

		resource "oci_dns_steering_policy" "oci_steering_policy_{{ $alternativeName }}_{{ $resourceSuffix }}" {
			provider        		= oci.dns_oci_{{ $resourceSuffix }}
			compartment_id  		= "{{ $.Data.Provider.GetOci.CompartmentOCID }}"
			display_name    		= "{{ $alternativeName }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
			template        		= "LOAD_BALANCE"
			ttl             		= 300
			health_check_monitor_id = oci_health_checks_ping_monitor.oci_health_checks_{{ $resourceSuffix }}.id

			{{- range $ip := $.Data.RecordData.IP }}
				answers {
					name 	= "{{ $ip.V4 }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
					rdata 	= "{{ $ip.V4 }}"
					rtype 	= "A"
				}
			{{- end }}

			rules {
				rule_type   = "FILTER"
				description = "Removes disabled answers."
				default_answer_data {
					answer_condition = "answer.isDisabled != true"
					should_keep      = "true"
				}
			}

			rules {
				rule_type   = "HEALTH"
				description = "Removes unhealthy target"
			}

			rules {
				rule_type = "WEIGHTED" 
				{{- range $ip := $.Data.RecordData.IP }}
					default_answer_data {
						answer_condition = "answer.name == '{{ $ip.V4 }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}'"
						value = 1
					}
				{{- end }}
			}

			rules {
				rule_type = "LIMIT"
				default_count = "1"
			}
		}

		resource "oci_dns_steering_policy_attachment" "dns_steering_policy_attachment_{{ $alternativeName }}_{{ $resourceSuffix }}" {
			provider       	 	= oci.dns_oci_{{ $resourceSuffix }}
			domain_name			= "{{ $alternativeName }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
			steering_policy_id 	= oci_dns_steering_policy.oci_steering_policy_{{ $resourceSuffix }}.id
			zone_id 			= local.matching_zone.id

		}

	output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
	  value = { "{{ $clusterID }}-endpoint" = "{{ $alternativeName }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}" }
	}
	{{- end }}
{{- end }}
