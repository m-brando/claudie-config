{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}

{{- range $_, $region := .Data.Regions }}

{{- $resourceSuffix := printf "%s_%s_%s" $region $specName $uniqueFingerPrint }}

provider "openstack" {
    auth_url                      = "{{ $.Data.Provider.GetOpenstack.AuthURL }}"
    application_credential_id     = "{{ $.Data.Provider.GetOpenstack.ApplicationCredentialID }}"
    application_credential_secret = "{{ $.Data.Provider.GetOpenstack.KeyFingerprint }}"
    region                        = "{{ $region }}"
    alias                         = "nodepool_{{ $resourceSuffix }}"
}
{{- end }}
