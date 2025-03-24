{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID 	       := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

{{- if hasExtension .Data "AlternativeNamesExtension" }}
	{{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}

	resource "oci_dns_rrset" "record_{{ $alternativeName }}_{{ $resourceSuffix }}" {
	   provider        = oci.dns_oci_{{ $resourceSuffix }}
	   domain          = "{{ $alternativeName }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
	   rtype           = "A"
	   zone_name_or_id = data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name

	   compartment_id  = "{{ $.Data.Provider.GetOci.CompartmentOCID }}"
	   {{- range $ip := $.Data.RecordData.IP }}
	   items {
	       domain  = "{{ $alternativeName }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
           rdata   = "{{ $ip.V4 }}"
           rtype   = "A"
           ttl     =  300
	   }
	   {{- end }}
	}


	output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
	  value = { "{{ $clusterID }}-{{ $alternativeName }}-endpoint" = oci_dns_rrset.record_{{ $alternativeName }}_{{ $resourceSuffix }}.domain }
	}

	{{- end }}
{{- end }}
