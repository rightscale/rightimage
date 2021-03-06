require 'chef/log'
require 'chef/mixin/shell_out'
class Chef::Provider
  include Chef::Mixin::ShellOut
end


# Use vmbuilder to generate a base virtual image.  We will use the image generated here for other recipes to add
# Cloud and Hypervisor specific details.
#
# When this is finished running, you should have a basic image ready in /mnt
#

action :install do
  mirror_date = "#{mirror_freeze_date[0..3]}/#{mirror_freeze_date[4..5]}/#{mirror_freeze_date[6..7]}"
  mirror_url = "http://#{node[:rightimage][:mirror]}/ubuntu_daily/#{mirror_date}"
  platform_codename = platform_codename(new_resource.platform_version)

  # Needed if constituent packages updated since image creation
  execute 'apt-get update -y > /dev/null'

  package "python-boto"
  package "python-vm-builder"


  # Overwrite the provided sources.list template or the kernel will be
  # installed from the upstream Ubuntu mirror. (w-6136)
  directory "/root/.vmbuilder/ubuntu" do
    owner "root"
    group "root"
    mode "0700"
    recursive true
    action :create
  end

  template "/root/.vmbuilder/ubuntu/sources.list.tmpl" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => true,
      :platform_codename => platform_codename
    )
    backup false
  end

  bash "cleanup" do
    flags "-ex"
    code <<-EOH
      umount -lf /dev/loop1 || true
      losetup -d /dev/loop1 || true
    EOH
  end

  temp_build_dir = node[:rightimage][:build_dir] + "/vmbuilder"

  #create bootstrap command
  bootstrap_cmd = "/usr/bin/vmbuilder xen ubuntu -o \
      --suite=#{platform_codename} \
      -d #{temp_build_dir} \
      --rootsize=2048 \
      --install-mirror=#{mirror_url} \
      --install-security-mirror=#{mirror_url} \
      --components=main,restricted,universe,multiverse \
      --lang=#{node[:rightimage][:lang]} --verbose "
  if node[:rightimage][:arch] == "i386"
    bootstrap_cmd << " --arch i386"
    bootstrap_cmd << " --addpkg libc6-xen"
  else
    bootstrap_cmd << " --arch amd64"
  end

  # https://bugs.launchpad.net/ubuntu/+source/vm-builder/+bug/1037607
  bootstrap_cmd << " --addpkg linux-image-generic" if node[:rightimage][:platform_version].to_f > 12.04

  Chef::Log.info "vmbuilder bootstrap command is: " + bootstrap_cmd

  log "Configuring Image..."

  # vmbuilder is defaulting to ext4 and I couldn't find any options to force the filesystem type so I just hacked this.
  # we restore it back to normal later.  
  bash "Comment out ext4 in /etc/mke2fs.conf" do
    flags "-ex"
    code <<-EOH
      sed -i '/ext4/,/}/ s/^/#/' /etc/mke2fs.conf 
    EOH
  end

  # TODO: Split this step up.
  bash "configure_image"  do
    user "root"
    cwd "/tmp"
    flags "-ex"
    code <<-EOH
      image_name=#{image_name}
    
      modprobe dm-mod

      if [ "#{platform_codename}" == "hardy" ]; then
        locale-gen en_US.UTF-8
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
      else
        source /etc/default/locale
        export LANG
      fi

      cat <<-EOS > /tmp/configure_script
#!/bin/bash -x

set -e 
set -x

chroot \\$1 localedef -i en_US -c -f UTF-8 en_US.UTF-8
chroot \\$1 ln -sf /usr/share/zoneinfo/UTC /etc/localtime
chroot \\$1 userdel -r ubuntu
chroot \\$1 rm -rf /home/ubuntu
chroot \\$1 rm -f /etc/hostname
chroot \\$1 touch /fastboot
chroot \\$1 apt-get purge -y apparmor apparmor-utils 
chroot \\$1 shadowconfig on
chroot \\$1  sed -i s/root::/root:*:/ /etc/shadow
chroot \\$1 ln -s /usr/bin/env /bin/env
chroot \\$1 rm -f /etc/rc?.d/*hwclock*
chroot \\$1 rm -f /etc/event.d/tty[2-6]
if [ -e \\$1/usr/bin/ruby1.9.1 ] && [ ! -e \\$1/usr/bin/ruby ]; then 
  chroot \\$1 ln -s /usr/bin/ruby1.9.1 /usr/bin/ruby
fi
if [ -e \\$1/usr/bin/ruby1.8 ] && [ ! -e \\$1/usr/bin/ruby ]; then 
  chroot \\$1 ln -s /usr/bin/ruby1.8 /usr/bin/ruby
fi
EOS
      chmod +x /tmp/configure_script
      #{bootstrap_cmd} --exec=/tmp/configure_script


      if [ "#{platform_codename}" == "hardy" ] ; then
        image_temp=$image_name
      else
        image_temp=`cat #{temp_build_dir}/xen.conf  | grep xvda1 | grep -v root  | sed "s#\'tap:aio:#{temp_build_dir}/##" | cut -c -9`
      fi


      loop_dev="/dev/loop1"

      base_raw_path="#{temp_build_dir}/root.img"

      sync
      umount -lf $loop_dev || true
      # Cleanup loopback stuff
      set +e
      losetup -a | grep $loop_dev
      [ "$?" == "0" ] && losetup -d $loop_dev
      set -e

      qemu-img convert -O raw #{temp_build_dir}/$image_temp $base_raw_path



      losetup $loop_dev $base_raw_path

      guest_root=#{guest_root}

      random_dir=/tmp/rightimage-$RANDOM
      mkdir $random_dir
      mount -o loop $loop_dev  $random_dir
      rsync -a --delete $random_dir/ $guest_root/ --exclude '/proc' --exclude '/dev' --exclude '/sys'
      umount $random_dir
      sync
      losetup -d $loop_dev
      rm -rf $random_dir

      mkdir -p $guest_root/var/man
      chroot $guest_root chown -R man:root /var/man


  EOH
  end


  # disable loading pata_acpi module - currently breaks acpid from discovering volumes attached to CDC KVM hypervisor, from bootstrap_centos, should be applicable to ubuntu though
  bash "blacklist pata_acpi" do
    code <<-EOF
      echo "blacklist pata_acpi"          > #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
      echo "install pata_acpi /bin/true" >> #{guest_root}/etc/modprobe.d/disable-pata_acpi.conf
    EOF
  end


  cookbook_file "#{guest_root}/tmp/GPG-KEY-RightScale" do
    source "GPG-KEY-RightScale"
    backup false
  end

  log "Adding rightscale gpg key to keyring"
  bash "install rightscale gpg key" do
    flags "-ex"
    code "chroot #{guest_root} apt-key add /tmp/GPG-KEY-RightScale"
  end

  # Hack: this cleans out cached copies of rightscale_software_ubuntu repo metadata
  # The files are too new and won't be updated but can get into a bad/inconsistent state
  # if they're updated before the gpg-key is added in
  execute "rm -f #{guest_root}/var/lib/apt/lists/*software*"
  execute "rm -f #{guest_root}/var/lib/apt/lists/partial/*software*"

  # Apt-get update after key is added, needed to install packages from rightscale-software
  execute "chroot #{guest_root} apt-get update > /dev/null"


  bash "Restore original ext4 in /etc/mke2fs.conf" do
    flags "-ex"
    code <<-EOH
      sed -i '/ext4/,/}/ s/^#//' /etc/mke2fs.conf 
    EOH
  end

  
  # Set DHCP timeout
  bash "dhcp timeout" do
    flags "-ex"
    code <<-EOH
      if [ "#{new_resource.platform_version.to_f < 12.04}" == "true" ]; then
        dhcp_ver="3"
      else
        dhcp_ver=""
      fi
      sed -i "s/#timeout.*/timeout 300;/" #{guest_root}/etc/dhcp$dhcp_ver/dhclient.conf
      rm -f #{guest_root}/var/lib/dhcp$dhcp_ver/*
    EOH
  end

  # dhclient on precise by default doesn't set the hostname on boot
  # while dhcpd on ubuntu 10.04 does. Ubuntu 13.04 has a script in contrib
  # called sethostname.sh that does the same thing that you can place your enter
  # hooks.  You may have to manually install it though, so revisit the issue at 
  # that point (w-5618)
  if new_resource.platform_version.to_f >= 12.04
    cookbook_file "#{guest_root}/etc/dhcp/dhclient-enter-hooks.d/hostname" do
      source "dhclient-hostname.sh"
      backup false
      mode "0644"
    end
  end

  log "Setting APT::Install-Recommends to false"
  bash "apt config" do
    flags "-ex"
    code <<-EOH
      echo "APT::Install-Recommends \"0\";" > #{guest_root}/etc/apt/apt.conf
    EOH
  end

  log "Disable HTTP pipeline on APT"
  bash "apt config pipeline" do
    flags "-ex"
    code <<-EOH
      echo "Acquire::http::Pipeline-Depth \"0\";" > #{guest_root}/etc/apt/apt.conf.d/99-no-pipelining
    EOH
  end

  # Collectd 5 is not currently supported by the RightScale monitoring servers
  # Pin to previous version from "precise" to avoid issues. These packages are
  # available from http://mirror.rightscale.com/rightscale_software_ubuntu (w-6281)
  cookbook_file "#{guest_root}/etc/apt/preferences.d/rightscale-collectd-pin-1001" do
    source "pin_collectd"
    backup false
  end

  ruby_block "install guest packages" do 
    block do
      loopback_package_install node[:rightimage][:guest_packages]
    end
  end

  # TODO: Add cleanup
  bash "cleanup" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      # Remove resolv.conf leftovers (w-5554)
      rm -rf $guest_root/etc/resolvconf/resolv.conf.d/original $guest_root/etc/resolvconf/resolv.conf.d/tail
      touch $guest_root/etc/resolvconf/resolv.conf.d/tail

      chroot #{guest_root} rm -rf /etc/init/plymouth*
      chroot #{guest_root} apt-get update > /dev/null
      chroot #{guest_root} apt-get clean
    EOH
  end

  execute "umount -lf #{temp_build_dir}/proc || true"

  directory temp_build_dir do
    action :delete
    recursive true
  end
end

action :repo_freeze do
  mirror_date = "#{mirror_freeze_date[0..3]}/#{mirror_freeze_date[4..5]}/#{mirror_freeze_date[6..7]}"

  template "#{guest_root}/etc/apt/sources.list" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => true,
      :platform_codename => platform_codename
    )
    backup false
  end

  # Need to apt-get update whenever the repo file is changed.
  execute "chroot #{guest_root} apt-get -y update > /dev/null"
end

action :repo_unfreeze do
  mirror_date = "latest"

  template "#{guest_root}/etc/apt/sources.list" do
    source "sources.list.erb"
    variables(
      :mirror_url => node[:rightimage][:mirror],
      :use_staging_mirror => node[:rightimage][:rightscale_staging_mirror],
      :mirror_date => mirror_date,
      :bootstrap => false,
      :platform_codename => platform_codename
    )
    backup false
  end

  # Need to apt-get update whenever the repo file is changed.
  execute "chroot #{guest_root} apt-get -y update > /dev/null"
end
