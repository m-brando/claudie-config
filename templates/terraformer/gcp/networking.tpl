{{- $clusterName       := .Data.ClusterData.ClusterName}}
{{- $clusterHash       := .Data.ClusterData.ClusterHash}}
{{- $specName          := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint := .Fingerprint }}

{{- range $_, $region := .Data.Regions}}

{{- if eq $.ClusterData.ClusterType "K8s" }}
variable "gcp_storage_disk_name_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  default = "storage-disk"
  type    = string
}
{{- end }}

resource "google_compute_network" "network_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  provider                = google.nodepool_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}
  name                    = "net-{{ $clusterHash }}-{{ $region }}-{{ $specName }}"
  auto_create_subnetworks = false
  description             = "Managed by Claudie for cluster {{ $clusterName }}-{{ $clusterHash }}"
}

resource "google_compute_firewall" "firewall_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  provider     = google.nodepool_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}
  name         = "fwl-{{ $clusterHash }}-{{ $region }}-{{ $specName }}"
  network      = google_compute_network.network_{{ $region }}_{{ $specName }}_{{ $uniqueFingerPrint }}.self_link
  description  = "Managed by Claudie for cluster {{ $clusterName }}-{{ $clusterHash }}"

{{- if eq $.Data.ClusterData.ClusterType "LB" }}
  {{- range $role := index $.Data.Metadata "roles" }}
  allow {
      protocol = "{{ $role.Protocol }}"
      ports = ["{{ $role.Port }}"]
  }
  {{- end }}
{{- end }}

{{- if eq $.Data.ClusterData.ClusterType "K8s" }}
  {{- if index $.Data.Metadata "loadBalancers" | targetPorts | isMissing 6443 }}
  allow {
      protocol = "TCP"
      ports    = ["6443"]
  }
  {{- end }}
{{- end }}

  allow {
    protocol = "UDP"
    ports    = ["51820"]
  }

  allow {
      protocol = "TCP"
      ports    = ["22"]
  }

  allow {
      protocol = "icmp"
   }

  source_ranges = [
      "0.0.0.0/0",
   ]
}
{{- end }}

