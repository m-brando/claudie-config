{{- $hostname          := .Data.Hostname }}
{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}

provider "aws" {
  secret_key = "${file("{{ $specName }}")}"
  access_key = "{{ .Data.Provider.GetAws.AccessKey }}"
  # we need to supply some aws region even though the records DNS are global.
  # this a requirement otherwise terraform will exit with an error.
  region     = "eu-central-1"
  alias      = "dns_aws_{{ $resourceSuffix }}"
  default_tags {
    tags = {
      Managed-by = "Claudie"
    }
  }
}

data "aws_route53_zone" "aws_zone_{{ $resourceSuffix }}" {
    provider  = aws.dns_aws_{{ $resourceSuffix }}
    name      = "{{ .Data.DNSZone }}"
}

{{- range $ip := .Data.RecordData.IP }}
resource "aws_route53_record" "record_{{ $hostname }}_{{ $resourceSuffix }}" {
    provider  = aws.dns_aws_{{ $resourceSuffix }}
    zone_id   = "${data.aws_route53_zone.aws_zone_{{ $resourceSuffix }}.zone_id}"
    name      = "{{ $hostname }}.${data.aws_route53_zone.aws_zone_{{ $resourceSuffix }}.name}"
    type      = "A"
    ttl       = 300
    records   = [
        "{{ $ip.V4 }}",
    ]
}
{{- end }}

{{- $clusterID := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}
output "{{ $clusterID }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
    value = { "{{ .Data.ClusterName }}-{{ .Data.ClusterHash }}-endpoint" = aws_route53_record.record_{{ $resourceSuffix }}.name }
}
