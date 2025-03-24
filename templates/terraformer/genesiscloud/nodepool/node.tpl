{{- $clusterName           := .Data.ClusterData.ClusterName}}
{{- $clusterHash           := .Data.ClusterData.ClusterHash}}
{{- $uniqueFingerPrint     := .Fingerprint }}
{{- $isKubernetesCluster   := eq .Data.ClusterData.ClusterType "K8s" }}
{{- $isLoadbalancerCluster := eq .Data.ClusterData.ClusterType "LB" }}


{{- range $nodepool := .Data.NodePools }}

{{- $region         := $nodepool.Details.Region }}
{{- $specName       := $nodepool.Details.Provider.SpecName }}
{{- $resourceSuffix := printf "%s_%s_%s" $region $specName $uniqueFingerPrint }}


{{- $sshKeyResourceName  := printf "key_%s_%s" $nodepool.Name $resourceSuffix }}
{{- $sshKeyName          := printf "key-%s-%s-%s-%s" $nodepool.Name $clusterHash $region $specName }}

resource "genesiscloud_ssh_key" "{{ $sshKeyResourceName }}" {
  provider   = genesiscloud.nodepool_{{ $resourceSuffix }}
  name       = "{{ $sshKeyName }}"
  public_key = file("./{{ $nodepool.Name }}")
}

    {{- range $node := $nodepool.Nodes }}

        {{- $volumeResourceName           := printf "%s_%s_volume" $node.Name $resourceSuffix }}
        {{- $volumeName                   := printf "%sd" $node.Name }}
        {{- $isWorkerNodeWithDiskAttached := and (not $nodepool.IsControl) (gt $nodepool.Details.StorageDiskSize 0) }}
        {{- $instanceResourceName         := printf "%s_%s" $node.Name $resourceSuffix }}
        {{- $floatingIPResourceName       := printf "%s_%s_ip" $node.Name $resourceSuffix }}
        {{- $floatingIPName               := printf "%sip" $node.Name }}
        {{- $securityGroupResourceName    := printf "claudie_security_group_%s" $resourceSuffix }}

        {{- if and ($isKubernetesCluster) ($isWorkerNodeWithDiskAttached) }}
            resource "genesiscloud_volume" "{{ $volumeResourceName }}" {
              provider = genesiscloud.nodepool_{{ $resourceSuffix }}
              name   = "{{ $volumeName }}"
              region = "{{ $region }}"
              size   = {{ $nodepool.Details.StorageDiskSize}}
              type   = "hdd"
            }
        {{- end }}

        resource "genesiscloud_floating_ip" "{{ $floatingIPResourceName }}" {
            provider = genesiscloud.nodepool_{{ $resourceSuffix }}
            name = "{{ $floatingIPName }}"
            region = "{{ $region }}"
            version = "ipv4"
        }

        resource "genesiscloud_instance" "{{ $instanceResourceName }}" {
          provider = genesiscloud.nodepool_{{ $resourceSuffix }}
          name   = "{{ $node.Name }}"
          region = "{{ $region }}"

          floating_ip_id = genesiscloud_floating_ip.{{ $floatingIPResourceName }}.id
          image    = replace(lower("{{ $nodepool.Details.Image }}"), " ", "-")
          type     = "{{ $nodepool.Details.ServerType }}"

        {{- if and ($isKubernetesCluster) ($isWorkerNodeWithDiskAttached) }}
          volume_ids = [
            genesiscloud_volume.{{ $volumeResourceName }}.id
          ]
        {{- end }}

          ssh_key_ids = [
            genesiscloud_ssh_key.{{ $sshKeyResourceName }}.id,
          ]

          security_group_ids = [
            genesiscloud_security_group.{{ $securityGroupResourceName }}.id
          ]

          {{- if $isLoadbalancerCluster }}
              metadata = {
                startup_script = <<EOF
#!/bin/bash
set -eo pipefail
sudo sed -i -n 's/^.*ssh-rsa/ssh-rsa/p' /root/.ssh/authorized_keys
echo 'PermitRootLogin without-password' >> /etc/ssh/sshd_config && echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# The '|| true' part in the following cmd makes sure that this script doesn't fail when there is no sshd service.
sshd_active=$(systemctl is-active sshd 2>/dev/null || true)
ssh_active=$(systemctl is-active ssh 2>/dev/null || true)

if [ $sshd_active = 'active' ]; then
    systemctl restart sshd
fi

if [ $ssh_active = 'active' ]; then
    systemctl restart ssh
fi
EOF
              }
          {{- end }}

          {{- if $isKubernetesCluster }}
              metadata = {
                startup_script = <<EOF
#!/bin/bash
set -eo pipefail

# Allow ssh as root
sudo sed -i -n 's/^.*ssh-rsa/ssh-rsa/p' /root/.ssh/authorized_keys
echo 'PermitRootLogin without-password' >> /etc/ssh/sshd_config && echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# The '|| true' part in the following cmd makes sure that this script doesn't fail when there is no sshd service.
sshd_active=$(systemctl is-active sshd 2>/dev/null || true)
ssh_active=$(systemctl is-active ssh 2>/dev/null || true)

if [ $sshd_active = 'active' ]; then
    systemctl restart sshd
fi

if [ $ssh_active = 'active' ]; then
    systemctl restart ssh
fi

mkdir -p /opt/claudie/data
            {{- if $isWorkerNodeWithDiskAttached }}
sleep 30

# it seems to be not possible to reference volume.id in the startupscript, thus the following hacky way of determining the volume id.
for id in $(ls /dev/disk/by-id); do
    device=$(readlink "/dev/disk/by-id/$id")
    device=$(basename $device)
    if ! blkid | grep -q "$device"; then
        disk=$device
        break;
    fi;
done

if [ -z "$disk" ]; then
    exit 1
fi

if ! grep -qs "/dev/$disk" /proc/mounts; then
  if ! blkid /dev/$disk | grep -q "TYPE=\"xfs\""; then
    mkfs.xfs -f /dev/$disk
  fi
  mount /dev/$disk /opt/claudie/data
  echo "/dev/$disk /opt/claudie/data xfs defaults 0 0" >> /etc/fstab
fi
            {{- end }}
EOF
              }
          {{- end }}
        }
    {{- end }}

output "{{ $nodepool.Name }}_{{ $specName }}_{{ $uniqueFingerPrint }}" {
  value = {
    {{- range $node := $nodepool.Nodes }}
        {{- $instanceResourceName := printf "%s_%s" $node.Name $resourceSuffix }}
        "${genesiscloud_instance.{{ $instanceResourceName }}.name}" = genesiscloud_instance.{{ $instanceResourceName }}.public_ip
    {{- end }}
  }
}
{{- end }}
