{{- $clusterName           := .Data.ClusterData.ClusterName}}
{{- $clusterHash           := .Data.ClusterData.ClusterHash}}
{{- $specName              := .Data.Provider.SpecName }}
{{- $uniqueFingerPrint     := .Fingerprint }}
{{- $isKubernetesCluster   := eq .Data.ClusterData.ClusterType "K8s" }}
{{- $isLoadbalancerCluster := eq .Data.ClusterData.ClusterType "LB" }}
{{- $LoadBalancerRoles     := .Data.LBData.Roles }}
{{- $K8sHasAPIServer       := .Data.K8sData.HasAPIServer }}

{{- range $_, $rn := .Data.RegionNetwork }}

  {{- $resourceSuffix := printf "%s_%s_%s_%s" $rn.Region $specName $uniqueFingerPrint }}
  {{- $privateNetResourceName  := printf "network_%s_%s"  $resourceSuffix .Data.ClusterData.ClusterType }}

  resource "openstack_networking_network_v2" "{{ $privateNetResourceName }}" {
    provider   = openstack.nodepool_{{ $resourceSuffix }}
    name = "{{ $privateNetResourceName }}"

    tags = [
      "managed-by:Claudie",
      "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
    ]
  }

  {{- $privateSubResourceName  := printf "subnet_%s_%s"  $resourceSuffix .Data.ClusterData.ClusterType }}

  resource "openstack_networking_subnet_v2" "{{ $privateSubResourceName }}" {
    provider   = openstack.nodepool_{{ $resourceSuffix }}
    name            = "{{ $privateSubResourceName }}"
    network_id      = openstack_networking_network_v2.{{ $privateNetResourceName }}.id
    cidr            = "10.0.0.0/16"
    ip_version      = 4
    gateway_ip      = "10.0.1.1"
    dns_nameservers = ["8.8.8.8", "1.1.1.1"]

    tags = [
      "managed-by:Claudie",
      "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
    ]
  }

  {{- $extNetworkResourceName  := printf "ext_net_%s"  $resourceSuffix }}

  data "openstack_networking_network_v2" "{{ $extNetworkResourceName }}" {
    provider   = openstack.nodepool_{{ $resourceSuffix }} 
    region = "{{ $rn.Region }}"
    name  = "{{ $rn.ExternalNetwork }}"
    external = true
  }

  {{- $routerResourceName  := printf "router_%s_%s"  $resourceSuffix .Data.ClusterData.ClusterType }}

  resource "openstack_networking_router_v2" "{{ $routerResourceName }}" {
    provider   = openstack.nodepool_{{ $resourceSuffix }} 
    name = "{{ $routerResourceName }}"
    external_network_id = data.openstack_networking_network_v2.{{ $extNetworkResourceName }}.id

    tags = [
      "managed-by:Claudie",
      "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
    ]
  }

  resource "openstack_networking_router_interface_v2" "router_iface" {
    provider   = openstack.nodepool_{{ $resourceSuffix }}
    router_id = openstack_networking_router_v2.{{ $routerResourceName }}.id
    subnet_id = openstack_networking_subnet_v2.{{ $privateSubResourceName }}.id
  }
{{- end }}
