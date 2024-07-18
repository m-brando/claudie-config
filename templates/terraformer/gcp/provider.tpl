{{- $specName          := .Data.Provider.SpecName }}
{{- $gcpProject        := .Data.Provider.GcpProject }}
{{- $uniqueFingerPrint := .Fingerprint }}

{{- range $_, $region := .Data.Regions}}
provider "google" {
  credentials = "${file("{{ specName }}")}"
  project     = "{{ gcpProject }}"
  region      = "{{ $region }}"
  alias       = "nodepool_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}"
}
{{- end}}
