{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID 	       := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

{{- if hasExtension .Data "AlternativeNamesExtension" }}
	{{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}

        {{- range $ip := $.Data.RecordData.IP }}
            {{- $escapedIPv4 := replaceAll $ip.V4 "." "_" }}
            {{- $recordResourceName := printf "record_%s_%s_%s" $alternativeName $escapedIPv4 $resourceSuffix }}

            resource "cloudflare_record" "{{ $recordResourceName }}" {
                provider = cloudflare.cloudflare_dns_{{ $resourceSuffix }}
                zone_id = data.cloudflare_zone.cloudflare_zone_{{ $resourceSuffix }}.id
                name = "{{ $alternativeName }}"
                value = "{{ $ip.V4 }}"
                type = "A"
                ttl = 300
            }
        {{- end }}

	output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
	  value = { "{{ $clusterID }}-{{ $alternativeName }}-endpoint" = format("%s.%s", "{{ $alternativeName }}", "{{ $.Data.DNSZone }}")}
	}

	{{- end }}
{{- end }}
