resource "openstack_networking_network_v2" "private_net" {
  name = "claudie-private-network"
}

resource "openstack_networking_subnet_v2" "private_subnet" {
  name            = "claudie-private-subnet"
  network_id      = openstack_networking_network_v2.private_net.id
  cidr            = "10.0.0.0/16"
  ip_version      = 4
  gateway_ip      = "10.0.1.1"
}

resource "openstack_networking_router_v2" "router" {
  name = "claudie-router"
  external_network_id = "6c928965-47ea-463f-acc8-6d4a152e9745"
}

resource "openstack_networking_router_interface_v2" "router_iface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.private_subnet.id
}
