# Elastic File System (EFS) for shared storage between tasks on ECS Fargate

# Wordpress is stateful application, so in order to deploy it on distributed 
# infrastructure, we need to share the same storage between the tasks.

# Access point in ECS task needs to be mounted at /var/www/html

# WordPress container conventions (Debian www-data). Not env knobs.
locals {
  posix_uid                = 33
  posix_gid                = 33
  access_point_path        = "/html"
  access_point_permissions = "775"
}

resource "aws_efs_file_system" "this" {
  creation_token   = "${var.name_prefix}-html"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = var.throughput_mode

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-efs" })
}

resource "aws_efs_mount_target" "this" {
  for_each = var.private_subnet_ids

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.this.id]
}

resource "aws_efs_access_point" "html" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = local.posix_uid
    gid = local.posix_gid
  }

  root_directory {
    path = local.access_point_path

    creation_info {
      owner_uid   = local.posix_uid
      owner_gid   = local.posix_gid
      permissions = local.access_point_permissions
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-efs-ap-html" })
}