output "public_ip" {
  value = [for i in range(var.ecs_count) : alicloud_instance.instance[i].public_ip]
}