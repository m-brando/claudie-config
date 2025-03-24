{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}
{{- $clusterID         := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}

provider "oci" {
  tenancy_ocid      = "{{ .Data.Provider.GetOci.TenancyOCID }}"
  user_ocid         = "{{ .Data.Provider.GetOci.UserOCID }}"
  fingerprint       = "{{ .Data.Provider.GetOci.KeyFingerprint }}"
  private_key_path  = "{{ $specName }}"
  region            = "eu-frankfurt-1"
  alias             = "dns_oci_{{ $resourceSuffix }}"
}

data "oci_dns_zones" "oci_zone_{{ $resourceSuffix }}" {
    provider        = oci.dns_oci_{{ $resourceSuffix }}
    compartment_id  = "{{ .Data.Provider.GetOci.CompartmentOCID }}"
    name            = "{{ .Data.DNSZone }}"
}

resource "oci_dns_rrset" "record_{{ $resourceSuffix }}" {
    provider        = oci.dns_oci_{{ $resourceSuffix }}
    domain          = "{{ .Data.Hostname }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
    rtype           = "A"
    zone_name_or_id = data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name

    compartment_id  = "{{ .Data.Provider.GetOci.CompartmentOCID }}"
    {{- range $ip := .Data.RecordData.IP }}
    items {
       domain = "{{ $.Data.Hostname }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
       rdata  = "{{ $ip.V4 }}"
       rtype  = "A"
       ttl    = 300
    }
    {{- end }}
}

output "{{ $clusterID }}_{{ $resourceSuffix }}" {
  value = { "{{ $clusterID }}-endpoint" = oci_dns_rrset.record_{{ $resourceSuffix }}.domain }
}
