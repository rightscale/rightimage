class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device target_raw_root do
  provider "block_device_volume"
  cloud "ec2"
  lineage lineage

  action :reset
end