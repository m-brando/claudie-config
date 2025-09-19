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
    name   = "{{ $keypairName }}"
    public_key = file("./{{ $nodepool.Name }}")
  }

  {{- range $node := $nodepool.Nodes }}

    {{- $serverResourceName           := printf "%s_%s" $node.Name $resourceSuffix }}
    {{- $networkResourceName          := printf "network_%s" $resourceSuffix }}
    {{- $volumeResourceName           := printf "volume_%s_%s" $node.Name $resourceSuffix }}

    resource "openstack_compute_instance_v2" "{{ $serverResourceName }}"  {
      provider          = openstack.nodepool_{{ $resourceSuffix }}
      name              = "{{ $node.Name }}"
      image_id          = "{{ $nodepool.Details.Image }}"
      flavor_name       = "{{ $nodepool.Details.ServerType }}"
      availability_zone = "{{ $nodepool.Details.Zone }}"
      key_pair          = openstack_compute_keypair_v2.{{ $keypairResourceName }}.id
      
      #need to change to our custom. waiting to quota increase ticket get resolved
      security_groups = ["default"]

      network {
        uuid = openstack_networking_network_v2.{{ $networkResourceName }}.id
      }

      tags = [
        "managed-by:Claudie"
        "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
      ]
    }

    {{- $fipResourceName  := printf "fip_%s_%s" $node.Name $resourceSuffix }}

    resource "openstack_networking_floatingip_v2" "{{ $fipResourceName }}" {
      provider   = openstack.nodepool_{{ $resourceSuffix }}
      # change this from input params
      pool = "Ext-Net"

      tags = [
        "managed-by:Claudie"
        "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
      ]
    }

    {{- $vmNetworkPort           := printf "vm_port_%s_%s" $node.Name $resourceSuffix }}
    {{- $vmNetworkPortName       := printf "vm-port-%s-%s" $node.Name $resourceSuffix }}

    data "openstack_networking_port_v2" "{{ $vmNetworkPort }}" {
      name = "{ $vmNetworkPortName }"
      device_id  = openstack_compute_instance_v2.{{ $serverResourceName }}.id
      network_id = openstack_compute_instance_v2.{{ $serverResourceName }}.network.1.uuid
    }

    {{- $fipAssociateName  := printf "fip_associate_%s_%s" $node.Name $resourceSuffix }}

    resource "openstack_networking_floatingip_associate_v2" "{{ $fipAssociateName }}" {
      floating_ip = openstack_networking_floatingip_v2.{{ $fipResourceName }}.address
      port_id     = data.openstack_networking_port_v2.{{ $vmNetworkPort }}.id
    }
    
    output "{{ $nodepool.Name }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
      value = {
        {{- range $node := $nodepool.Nodes }}
            {{- $serverResourceName := printf "%s_%s" $node.Name $resourceSuffix }}
            {{- $fipResourceName  := printf "fip_%s_%s" $node.Name $resourceSuffix }}
            "${openstack_compute_instance_v2.{{ $serverResourceName }}.name}" = openstack_networking_floatingip_associate_v2.{{ $fipResourceName }}.floating_ip
        {{- end }}
      }
    }
  {{- end }}
{{- end }}
