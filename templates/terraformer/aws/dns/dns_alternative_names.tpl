{{- $hostname          := .Data.Hostname }}
{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID 	       := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

{{- if hasExtension .Data "AlternativeNamesExtension" }}
	{{- range $_, $alternativeName := .Data.AlternativeNamesExtension.Names }}
    {{- range $index,$ip := $.Data.RecordData.IP }}
      resource "aws_route53_record" "record_{{ $alternativeName }}_{{ $index }}_{{ $resourceSuffix }}" {
        provider  = aws.dns_aws_{{ $resourceSuffix }}
        zone_id   = "${data.aws_route53_zone.aws_zone_{{ $resourceSuffix }}.zone_id}"
        name      = "{{ $alternativeName }}.${data.aws_route53_zone.aws_zone_{{ $resourceSuffix }}.name}"
        type      = "A"
        ttl       = 300
        records   = [
          "{{ $ip.V4 }}",
        ]

        set_identifier = "record_{{ $alternativeName }}_{{ $index }}_{{ $resourceSuffix }}"
        health_check_id = aws_route53_health_check.hc_{{ $hostname }}_{{ $index }}.id

        weighted_routing_policy {
          weight = 1
          }
      }
    {{- end }}

	output "{{ $clusterID }}_{{ $alternativeName }}_{{ $resourceSuffix }}" {
    value = { "{{ $clusterID }}-{{ $alternativeName }}-endpoint" = "{{ $alternativeName }}.${data.aws_route53_zone.aws_zone_{{ $resourceSuffix }}.name}" }
	}
	{{- end }}
{{- end }}
