resource "openstack_compute_instance_v2" "claudie-test" {
  name            = "claudie-test"
  image_id        = "7080933e-0586-44a8-8c33-459affa11782"
  flavor_name       = "d2-2"
  availability_zone =  "nova"
#  key_pair        = openstack_compute_keypair_v2.claudie-keypair
  security_groups = ["default"]

  network {
    uuid = openstack_networking_network_v2.private_net.id
  }
}
