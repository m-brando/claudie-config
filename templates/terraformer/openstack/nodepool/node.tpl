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

    {{- $instanceResourceName         := printf "%s_%s" $node.Name $resourceSuffix }}
    {{- $networkResourceName          := printf "network_%s" $resourceSuffix }}
    {{- $volumeResourceName           := printf "volume_%s_%s" $node.Name $resourceSuffix }}
    {{- $isWorkerNodeWithDiskAttached := and (not $nodepool.IsControl) (gt $nodepool.Details.StorageDiskSize 0) }}

    resource "openstack_compute_instance_v2" "{{ $instanceResourceName }}"  {
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
        "managed-by:Claudie",
        "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
      ]

      {{- if $isKubernetesCluster }}
        user_data = <<-EOF
        #cloud-config

        runcmd:
          - sed -n 's/^.*ssh-rsa/ssh-rsa/p' /root/.ssh/authorized_keys > /root/.ssh/temp
          - cat /root/.ssh/temp > /root/.ssh/authorized_keys
          - rm /root/.ssh/temp

          # Modify SSH configuration
          - echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          - echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
          - echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          - echo 'PubkeyAcceptedKeyTypes=+ssh-rsa' >> /etc/ssh/sshd_config

          # Restart SSH service if it's running
          - |
            sshd_active=$(systemctl is-active sshd 2>/dev/null || true)
            ssh_active=$(systemctl is-active ssh 2>/dev/null || true)
            if [ "$sshd_active" = "active" ]; then
              systemctl restart sshd
            fi
            if [ "$ssh_active" = "active" ]; then
              systemctl restart ssh
            fi
        EOF
        {{- end }}
    }

    {{- $fipResourceName  := printf "fip_%s_%s" $node.Name $resourceSuffix }}

    resource "openstack_networking_floatingip_v2" "{{ $fipResourceName }}" {
      provider   = openstack.nodepool_{{ $resourceSuffix }}
      pool = "{{ $nodepool.Details.ExternalNetworkName }}"

      tags = [
        "managed-by:Claudie",
        "claudie-cluster:{{ $clusterName }}-{{ $clusterHash }}"
      ]
    }

    {{- $vmNetworkPort           := printf "vm_port_%s_%s" $node.Name $resourceSuffix }}
    {{- $vmNetworkPortName       := printf "vm-port-%s-%s" $node.Name $resourceSuffix }}

    data "openstack_networking_port_v2" "{{ $vmNetworkPort }}" {
      provider   = openstack.nodepool_{{ $resourceSuffix }}
      device_id  = openstack_compute_instance_v2.{{ $instanceResourceName }}.id
      network_id = openstack_compute_instance_v2.{{ $instanceResourceName }}.network.0.uuid
    }

    {{- $fipAssociateName  := printf "fip_associate_%s_%s" $node.Name $resourceSuffix }}

    resource "openstack_networking_floatingip_associate_v2" "{{ $fipAssociateName }}" {
      provider   = openstack.nodepool_{{ $resourceSuffix }}
      floating_ip = openstack_networking_floatingip_v2.{{ $fipResourceName }}.address
      port_id     = data.openstack_networking_port_v2.{{ $vmNetworkPort }}.id
    }

    {{- if $isKubernetesCluster }}
      {{- /* Only Mount disk for Worker nodes that have a non-zero requested disk size */}}
      {{- if $isWorkerNodeWithDiskAttached }}
        {{- $volumeName                   := printf "%sd" $node.Name }}
        {{- $volumeResourceName           := printf "%s_%s_volume" $node.Name $resourceSuffix }}
        {{- $volumeAttachmentResourceName := printf "%s_att" $volumeResourceName }}

        resource "openstack_blockstorage_volume_v3" "{{ $volumeResourceName }}" {
          provider   = openstack.nodepool_{{ $resourceSuffix }}
          name    = "{{ $volumeName }}"
          size    = "{{ $nodepool.Details.StorageDiskSize }}"
          region  = "{{ $nodepool.Details.Region }}"
        }

        resource "openstack_compute_volume_attach_v2" "volume_attach" {
          provider   = openstack.nodepool_{{ $resourceSuffix }}
          instance_id = openstack_compute_instance_v2.{{ $instanceResourceName }}.id
          volume_id   = openstack_blockstorage_volume_v3.{{ $volumeResourceName }}.id
        }
      {{- end }}
    {{- end }}

    output "{{ $nodepool.Name }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
      value = {
        {{- range $node := $nodepool.Nodes }}
            {{- $instanceResourceName := printf "%s_%s" $node.Name $resourceSuffix }}
            {{- $fipResourceName  := printf "fip_%s_%s" $node.Name $resourceSuffix }}
            "${openstack_compute_instance_v2.{{ $instanceResourceName }}.name}" = openstack_networking_floatingip_associate_v2.{{ $fipAssociateName }}.floating_ip
        {{- end }}
      }
    }
  {{- end }}
{{- end }}
