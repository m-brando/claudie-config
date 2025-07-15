{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID 	       := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

{{- if hasExtension .Data "AlternativeNamesExtension" }}
	{{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}
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
