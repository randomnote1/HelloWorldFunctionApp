#A unique prefix to apply to all the resources in this solution.
resource_name_prefix = "Reist"

# Address space of the virtual network.
virtual_network_address_space = ["10.3.65.0/24"]

# Specify the IP address ranges which are allowed to access all the Azure resources using CIDR notation.
admin_ip_address_ranges = {
  allowDanReist   = "73.101.55.199"
}
