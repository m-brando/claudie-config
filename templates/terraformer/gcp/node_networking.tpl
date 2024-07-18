{{- $clusterName       := .Data.ClusterData.ClusterName }}
{{- $clusterHash       := .Data.ClusterData.ClusterHash }}
{{- $uniqueFingerPrint := $.Fingerprint }}

{{- range $_, $nodepool := .NodePools }}

{{- $region   := $nodepool.NodePool.Region }}
{{- $specName := $nodepool.NodePool.Provider.SpecName }}

resource "google_compute_subnetwork" "{{ $nodepool.Name }}_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}_subnet" {
  provider      = google.nodepool_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}
  name          = "snt-{{ $clusterHash }}-{{ $region }}-{{ $nodepool.Name }}"
  network       = google_compute_network.network_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}.self_link
  ip_cidr_range = "{{index $.Data.Metadata (printf "%s-subnet-cidr" $nodepool.Name) }}"
  description   = "Managed by Claudie for cluster {{ $clusterName }}-{{ $clusterHash }}"
}

{{- end }}
