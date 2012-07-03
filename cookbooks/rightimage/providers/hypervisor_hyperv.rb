class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install_kernel do
  
  #raise "Only centos 6 is supported" unless node[:rightimage][:platform] == "centos" && node[:rightimage][:platform_verion] == "6.2"
  
  LIS_DIR_GUEST = "/tmp/lis_install"
  LIS_DIR_HOST = "#{guest_root}#{LIS_DIR_GUEST}"
  LIS_PACKAGE = "#{LIS_DIR_HOST}/CENTOS%20LIS%20BETA3.3.zip"
  
  directory LIS_DIR_HOST do
    recursive true
  end
  
  remote_file LIS_PACKAGE do
    source "http://devs-us-west.s3.amazonaws.com/caryp/azure/CENTOS%20LIS%20BETA3.3.zip"
  end
 
  bash "install Linux Integration Services package" do
    flags "-ex"
    cwd LIS_DIR_HOST
    not_if "rpm --root #{guest_root} -qa microsoft-hyper-v|grep microsoft"
    code <<-EOH
      guest_root=#{guest_root}
      lis_dir_host=#{LIS_DIR_HOST}
      lis_dir_guest=#{LIS_DIR_GUEST}
      package=#{LIS_PACKAGE}
      
      # unzip LIS package
      unzip -o $package
      chmod +x $lis_dir_host/install.sh
      
      # lay down wrapper script for chroot run
      # since install.sh assumes you are in the directory containing the 
      # packages.  Too bad chroot doesn't have a --cwd option.
      cat > $lis_dir_host/run.sh <<-EOF
#!/bin/bash -ex
cd /tmp/lis_install
./install.sh
EOF
      
      # run install
      chmod +x $lis_dir_host/run.sh
      chroot $guest_root $lis_dir_guest/run.sh

      # Erase currently installed kernels and associated packages
      for kernel_pkg in `rpm --root $guest_root -qa kernel kernel-*`; do
        rpm --root $guest_root --erase --nodeps $kernel_pkg
      done

      # Force-set kernel version due to incompatibility with 2.6.32-220.17.1
      good_kernel="2.6.32-220.13.1.el6.x86_64"
      package_list="kernel kernel-headers kernel-firmware"
      packages_to_install=""
      for package in $package_list; do
        packages_to_install="$packages_to_install $package-$good_kernel"
      done
      yum -c /tmp/yum.conf --installroot=$guest_root -y install $packages_to_install

      # Agent install attempts to use kernel on host instead of the guest
      rm -f $guest_root/initr* $guest_root/boot/initr*$(uname -r)*

      # Kill services started automatically during package installs
      killall hv_kvp_daemon
    EOH
  end
 
end

action :install_tools do
  
  remote_file "#{LIS_DIR_HOST}/WALinuxAgent.rpm" do
    source "http://devs-us-west.s3.amazonaws.com/caryp/azure/WALinuxAgent-1.0-1.noarch.rpm"
  end
  
  bash "install WAZ agent" do
    flags "-ex"
    cwd LIS_DIR_HOST
    not_if "rpm --root #{guest_root} -qa WALinuxAgent|grep WA"
    code <<-EOH
      guest_root=#{guest_root}
      yum -c /tmp/yum.conf --installroot=$guest_root -y install WALinuxAgent.rpm
    EOH
  end
end
