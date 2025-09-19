{{- $clusterName           := .Data.ClusterData.ClusterName}}
{{- $clusterHash           := .Data.ClusterData.ClusterHash}}
{{- $uniqueFingerPrint     := .Fingerprint }}
{{- $isKubernetesCluster   := eq .Data.ClusterData.ClusterType "K8s" }}
{{- $isLoadbalancerCluster := eq .Data.ClusterData.ClusterType "LB" }}

{{- range $nodepool := .Data.NodePools }}

{{- $region         := $nodepool.Details.Region }}
{{- $specName       := $nodepool.Details.Provider.SpecName }}
{{- $resourceSuffix := printf "%s_%s_%s" $region $specName $uniqueFingerPrint }}

{{- $keypairResourceName  := printf "key_%s_%s" $nodepool.Name $resourceSuffix }}
{{- $keypairName          := printf "key-%s-%s-%s" $nodepool.Name $clusterHash $specName }}

  resource "openstack_compute_keypair_v2" "{{ $keypairResourceName }}" {
    provider   = openstack.nodepool_{{ $resourceSuffix }}
    key_name   = "{{ $keypairName }}"
    public_key = file("./{{ $nodepool.Name }}")
    tags = {
      Name            = "{{ $keypairName }}"
      Claudie-cluster = "{{ $clusterName }}-{{ $clusterHash }}"
    }
  }

  {{- range $node := $nodepool.Nodes }}

  {{- $serverResourceName           := printf "%s_%s" $node.Name $resourceSuffix }}
  {{- $networkResourceName          := printf "%s_%s_network" $nodepool.Name $resourceSuffix }}
  {{- $volumeResourceName           := printf "%s_%s_volume" $node.Name $resourceSuffix }}

  resource "openstack_compute_instance_v2" "{{ $serverResourceName }}"  {
    provider          = openstack.nodepool_{{ $resourceSuffix }}
    name              = "{{ $node.Name }}"
    image_id          = "{{ $nodepool.Details.Image }}"
    flavor_name       = "{{ $nodepool.Details.ServerType }}"
    availability_zone = "{{ $nodepool.Details.Zone }}"
    key_pair          = openstack_compute_keypair_v2.{{ $keypairResourceName }}.id,
    
    #need to change to our custom. waiting to quota increase ticket get resolved
    security_groups = ["default"]

    network {
      uuid = openstack_networking_network_v2.{{ $networkResourceName }}.id
    }

    tags = {
      "managed-by"      : "Claudie"
      "claudie-cluster" : "{{ $clusterName }}-{{ $clusterHash }}"
    }
  }
{{- end }}


output "{{ $nodepool.Name }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  value = {
    {{- range $node := $nodepool.Nodes }}
        {{- $serverResourceName := printf "%s_%s" $node.Name $resourceSuffix }}
        "${openstack_compute_instance_v2.{{ $serverResourceName }}.name}" = openstack_compute_instance_v2.{{ $serverResourceName }}.ipv4_address
    {{- end }}
  }
}
{{- end }}
