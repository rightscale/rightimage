rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: default
#
# Copyright 2011, RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef::Recipe
  include RightScale::RightImage::Helper
end

directory target_temp_root do
  owner "root"
  group "root"
  recursive true
end

packages = {
"ubuntu" => ["libxml2-dev", "libxslt1-dev"],
"centos" => ["libxml2-devel", "libxslt-devel"]
}
packages[node[:platform]].each do |p| 
  r = package p do 
    action :nothing 
  end
  r.run_action(:install)
end

include_recipe "rightimage::base_#{node.platform.downcase}"
include_recipe "rightimage::cloud_add_#{node.rightimage.cloud.downcase}" if node.rightimage.cloud
include_recipe "rightimage::do_destroy_loopback"
include_recipe "rightimage::upload_file_to_s3"
rs_utils_marker :end
