{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}
{{- $resourceSuffix    := printf "%s_%s" $specName $uniqueFingerPrint }}

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

resource "oci_dns_steering_policy" "oci_steering_policy_{{ $resourceSuffix }}" {
  provider        = oci.dns_oci_{{ $resourceSuffix }}
  compartment_id  = "{{ .Data.Provider.GetOci.CompartmentOCID }}"
  display_name    = "{{ .Data.Hostname }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
  template        = "LOAD_BALANCE"
  ttl             = 300

  {{- range $ip := .Data.RecordData.IP }}
  answers {
    name = "{{ $ip.V4 }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"
    rdata = "{{ $ip.V4 }}"
    rtype = "A"
  }
  {{- end }}

  rules {
		rule_type = "WEIGHTED"
    {{- range $ip := .Data.RecordData.IP }}
    default_answer_data {
      answer_condition = "answer.name == '"{{ $ip.V4 }}.${data.oci_dns_zones.oci_zone_{{ $resourceSuffix }}.name}"'"
      value = 1
    }
    {{- end }}
  }
}

{{- $clusterID := printf "%s-%s" .Data.ClusterName .Data.ClusterHash }}
output "{{ $clusterID }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  value = { "{{ .Data.ClusterName }}-{{ .Data.ClusterHash }}-endpoint" = oci_dns_rrset.record_{{ $resourceSuffix }}.domain }
}
