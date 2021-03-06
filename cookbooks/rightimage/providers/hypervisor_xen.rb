class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end


action :install_kernel do
 
  bash "install xen kernel" do
    flags "-ex"
    if new_resource.platform_version <= 10.04
      ubuntu_kernel_packages = 'linux-image-ec2 linux-headers-ec2 grub-legacy-ec2'
    end

    code <<-EOH
      # Install to guest. 
      guest_root=#{guest_root}

      case #{new_resource.platform} in
        "centos"|"rhel")
          if [ #{new_resource.platform_version.to_i} -lt 6 ]; then
            chroot $guest_root yum -y remove kernel
            yum -c /tmp/yum.conf --installroot=$guest_root -y install kernel-xen kmod-xfs-xen
          fi

          kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

          if [ #{node[:rightimage][:platform_version].to_i} -le 6 ]; then
            ramdisk="initrd-${kernel_version}"
          else
            ramdisk="initramfs-${kernel_version}.img"
          fi
    
          rm -f $guest_root/boot/initr* $guest_root/initr*
          chroot $guest_root mkinitrd --with=xennet --with=xenblk --with=ext3 --with=jbd --preload=xenblk -v $ramdisk $kernel_version
          mv $guest_root/$ramdisk $guest_root/boot/.
          ;;
        "ubuntu")
          # Remove any installed kernels
#          for i in `chroot $guest_root dpkg --get-selections linux-headers* linux-image*|sed "s/install//g"`; do chroot $guest_root env DEBIAN_FRONTEND=noninteractive apt-get -y purge $i; done

          chroot $guest_root apt-get -y install #{ubuntu_kernel_packages}
          chroot $guest_root apt-get clean
          ;;
        esac
    EOH
  end
end

action :install_tools do
  # RightLink requires local time to be accurate (w-5025
  bash "setup NTP" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}

      # Use of independent clock recommended by Citrix: http://support.citrix.com/article/CTX128034
      # No longer needed/supported on CentOS 6/Ubuntu 12
      case #{new_resource.platform} in
      "centos"|"rhel")
        if [ #{new_resource.platform_version.to_i} -lt 6 ]; then
          set +e
          grep "xen.independent_wallclock=1" $guest_root/etc/sysctl.conf
          [ "$?" == "1" ] && echo "xen.independent_wallclock=1" >> $guest_root/etc/sysctl.conf
          set -e
        fi
        ;;
      "ubuntu")
        if [ #{new_resource.platform_version.to_i} -lt 12 ]; then
          echo "xen.independent_wallclock=1" > $guest_root/etc/sysctl.d/60-rightscale-ntp.conf
        fi
        ;;
      esac
    EOH
  end
end
