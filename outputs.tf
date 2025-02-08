output "vm_public_ip" {
  value = aws_instance.vm_public.public_ip
}

output "vm_private_ip" {
  value = aws_instance.vm_private.private_ip
}
