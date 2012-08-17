## when pasting a key into a json file, make sure to use the following command: 
## sed -e :a -e '$!N;s/\n/\\n/;ta' /path/to/key
## this seems not to work on os x
class Chef::Node
 include RightScale::RightImage::Helper
end

set_unless[:rightimage][:debug] = false
set[:rightimage][:lang] = "en_US.UTF-8"
set_unless[:rightimage][:root_size_gb] = "10"
set[:rightimage][:build_dir] = "/mnt/vmbuilder"
set[:rightimage][:guest_root] = "/mnt/image"
set_unless[:rightimage][:hypervisor] = "xen"
set[:rightimage][:mirror] = "cf-mirror.rightscale.com"
set_unless[:rightimage][:cloud] = "ec2"
set[:rightimage][:root_mount][:label_dev] = "ROOT"
set[:rightimage][:root_mount][:dev] = "LABEL=#{rightimage[:root_mount][:label_dev]}"
set_unless[:rightimage][:image_source_bucket] = "rightscale-us-west-2"
set_unless[:rightimage][:base_image_bucket] = "rightscale-rightimage-base-dev"
set_unless[:rightimage][:platform] = guest_platform
set_unless[:rightimage][:platform_version] = guest_platform_version
set_unless[:rightimage][:arch] = guest_arch

if timestamp
  if rightimage[:platform] == "ubuntu"
    set[:rightimage][:mirror_date] = "#{timestamp[0..3]}/#{timestamp[4..5]}/#{timestamp[6..7]}"
    set[:rightimage][:mirror_url] = "http://#{node[:rightimage][:mirror]}/ubuntu_daily/#{node[:rightimage][:mirror_date]}"
  else
    set[:rightimage][:mirror_date] = timestamp[0..7]
  end
else
  set[:rightimage][:mirror_date] = nil
end


case node[:rightimage][:hypervisor]
when "xen" then set[:rightimage][:image_type] = "vhd"
when "esxi" then set[:rightimage][:image_type] = "vmdk"
when "kvm" then set[:rightimage][:image_type] = "qcow2"
when "hyperv" then set[:rightimage][:image_type] = "msvhd"
else raise ArgumentError, "don't know what image format to use for #{node[:rightimage][:hypervisor]}!"
end

set[:rightimage][:common_guest_packages] = "acpid"
rightimage[:common_guest_packages] << " autoconf"
rightimage[:common_guest_packages] << " automake"
rightimage[:common_guest_packages] << " bison"
rightimage[:common_guest_packages] << " curl"
rightimage[:common_guest_packages] << " flex"
rightimage[:common_guest_packages] << " libtool"
rightimage[:common_guest_packages] << " libxml2"
rightimage[:common_guest_packages] << " logrotate"
rightimage[:common_guest_packages] << " nscd"
rightimage[:common_guest_packages] << " openssh-server"
rightimage[:common_guest_packages] << " openssl"
rightimage[:common_guest_packages] << " screen"
rightimage[:common_guest_packages] << " subversion"
rightimage[:common_guest_packages] << " sysstat"
rightimage[:common_guest_packages] << " tmux"
rightimage[:common_guest_packages] << " unzip"

# set base os packages
case rightimage[:platform]
when "ubuntu"
  set[:rightimage][:guest_packages] = "binutils"
  rightimage[:guest_packages] << " build-essential"
  rightimage[:guest_packages] << " ca-certificates"
  rightimage[:guest_packages] << " dhcp3-client"
  rightimage[:guest_packages] << " dmsetup"
  rightimage[:guest_packages] << " emacs"
  rightimage[:guest_packages] << " git-core"
  rightimage[:guest_packages] << " iptraf"
  rightimage[:guest_packages] << " irb"
  rightimage[:guest_packages] << " libarchive-dev"
  rightimage[:guest_packages] << " liberror-perl"
  rightimage[:guest_packages] << " libopenssl-ruby1.8"
  rightimage[:guest_packages] << " libreadline-ruby1.8"
  rightimage[:guest_packages] << " libshadow-ruby1.8"
  rightimage[:guest_packages] << " libxml2-dev"
  rightimage[:guest_packages] << " libxslt1-dev"
  rightimage[:guest_packages] << " mailutils"
  rightimage[:guest_packages] << " ncurses-dev"
  rightimage[:guest_packages] << " postfix"
  rightimage[:guest_packages] << " rake"
  rightimage[:guest_packages] << " rdoc1.8"
  rightimage[:guest_packages] << " readline-common"
  rightimage[:guest_packages] << " rsync"
  rightimage[:guest_packages] << " ruby1.8"
  rightimage[:guest_packages] << " ruby1.8-dev"
  rightimage[:guest_packages] << " sqlite3"
  rightimage[:guest_packages] << " ubuntu-standard"
  rightimage[:guest_packages] << " vim"
  rightimage[:guest_packages] << " zlib1g-dev"

  case rightimage[:platform_version]
  when "8.04"
  when "10.04"
  when "10.10"
    rightimage[:guest_packages] << " libdigest-sha1-perl"
    rightimage[:guest_packages] << " libreadline5-dev"
    rightimage[:guest_packages] << " linux-headers-virtual"
  else
    rightimage[:guest_packages] << " libreadline-gplv2-dev"
  end

  set[:rightimage][:host_packages] = "ca-certificates"
  rightimage[:host_packages] << " openjdk-6-jre"
  rightimage[:host_packages] << " openssl"

  case rightimage[:platform_version]
  when "8.04"
    rightimage[:guest_packages] << " debian-helper-scripts"
    rightimage[:guest_packages] << " sysv-rc-conf"
    rightimage[:host_packages] << " ubuntu-vm-builder"
  when "9.10"
    rightimage[:host_packages] << " python-vm-builder-ec2"
  when "10.04"
    if rightimage[:cloud] == "ec2"
      rightimage[:host_packages] << " devscripts"
      rightimage[:host_packages] << " python-vm-builder-ec2"
    else
      rightimage[:host_packages] << " devscripts"
    end
  when "10.10"
    rightimage[:guest_packages] << " linux-image-virtual"
    rightimage[:host_packages] << " devscripts"
  when "12.04"
    rightimage[:guest_packages] << " linux-image-virtual"
    rightimage[:host_packages] << " devscripts"
    rightimage[:host_packages] << " liburi-perl"
  else
     rightimage[:host_packages] << " devscripts"
  end
when "centos","rhel"
  set[:rightimage][:guest_packages] << "bwm-ng"
  rightimage[:guest_packages] << " compat-gcc-34-g77"
  rightimage[:guest_packages] << " compat-libstdc++-296"
  rightimage[:guest_packages] << " createrepo"
  rightimage[:guest_packages] << " cvs"
  rightimage[:guest_packages] << " dhclient"
  rightimage[:guest_packages] << " fping"
  rightimage[:guest_packages] << " gcc*"
  rightimage[:guest_packages] << " git"
  rightimage[:guest_packages] << " libarchive-devel"
  rightimage[:guest_packages] << " libxml2-devel"
  rightimage[:guest_packages] << " libxslt"
  rightimage[:guest_packages] << " libxslt-devel"
  rightimage[:guest_packages] << " lynx"
  rightimage[:guest_packages] << " mlocate"
  rightimage[:guest_packages] << " mutt"
  rightimage[:guest_packages] << " nano"
  rightimage[:guest_packages] << " openssh-askpass"
  rightimage[:guest_packages] << " openssh-clients"
  rightimage[:guest_packages] << " pkgconfig"
  rightimage[:guest_packages] << " redhat-lsb"
  rightimage[:guest_packages] << " redhat-rpm-config"
  rightimage[:guest_packages] << " rpm-build"
  rightimage[:guest_packages] << " ruby"
  rightimage[:guest_packages] << " ruby-devel"
  rightimage[:guest_packages] << " ruby-docs"
  rightimage[:guest_packages] << " ruby-irb"
  rightimage[:guest_packages] << " ruby-libs"
  rightimage[:guest_packages] << " ruby-mode"
  rightimage[:guest_packages] << " ruby-rdoc"
  rightimage[:guest_packages] << " ruby-ri"
  rightimage[:guest_packages] << " ruby-tcltk"
  rightimage[:guest_packages] << " sudo"
  rightimage[:guest_packages] << " swig"
  rightimage[:guest_packages] << " telnet"
  rightimage[:guest_packages] << " vim-common"
  rightimage[:guest_packages] << " vim-enhanced"
  rightimage[:guest_packages] << " wget"
  rightimage[:guest_packages] << " xfsprogs"
  rightimage[:guest_packages] << " yum-utils"

  set[:rightimage][:host_packages] = "swig"

  extra_el_packages =
    if el6?
      " compat-db43" +
      " compat-expat1" +
      " openssl098e"
    else
      " db4" +
      " expat" +
      " openssl"
    end

  rightimage[:guest_packages] << extra_el_packages
  rightimage[:host_packages] << extra_el_packages
when "suse"
  set[:rightimage][:guest_packages] = "gcc"

  set[:rightimage][:host_packages] = "kiwi"
end

# Append list of common packages to platform specific package list
set[:rightimage][:guest_packages] << " " + rightimage[:common_guest_packages]

# set cloud stuff
# TBD Refactor this block to use consistent naming, figure out how to move logic into cloud providers
case rightimage[:cloud]
  when "ec2", "eucalyptus" 
    set[:rightimage][:root_mount][:dump] = "0" 
    set[:rightimage][:root_mount][:fsck] = "0" 
    set[:rightimage][:fstab][:ephemeral] = true
    # Might have to double check don't know if maverick should use kernel linux-image-ec2 or not
    set[:rightimage][:swap_mount] = "/dev/sda3" unless rightimage[:arch] == "x86_64"
    set[:rightimage][:ephemeral_mount] = "/dev/sdb"

    case rightimage[:platform]
      when "ubuntu" 
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults,nobootwait"
        set[:rightimage][:fstab][:swap] = "defaults,nobootwait"
        if rightimage[:platform_version].to_f >= 10.10
          set[:rightimage][:ephemeral_mount] = "/dev/xvdb"
          set[:rightimage][:swap_mount] = "/dev/xvda3" unless rightimage[:arch]  == "x86_64"
        end
      when "centos", "rhel"
        set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
        set[:rightimage][:fstab][:swap] = "defaults"

        # CentOS 6.1-6.2 start SCSI device naming from e
        if rightimage[:platform_version].to_i == 6
          if rightimage[:platform_version].to_f > 6.1
            set[:rightimage][:ephemeral_mount] = "/dev/xvdf"
            set[:rightimage][:swap_mount] = "/dev/xvde3"  unless rightimage[:arch]  == "x86_64"
          else
            set[:rightimage][:ephemeral_mount] = "/dev/xvdb"
            set[:rightimage][:swap_mount] = "/dev/xvda3"  unless rightimage[:arch]  == "x86_64"
          end
        end
    end
  else 
    case rightimage[:hypervisor]
    when "xen"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:grub][:root_device] = "/dev/xvda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "kvm"
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:ephemeral_mount] = "/dev/vdb"
      set[:rightimage][:fstab][:ephemeral_mount_opts] = "defaults"
      set[:rightimage][:grub][:root_device] = "/dev/vda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    when "esxi", "hyperv"
      set[:rightimage][:ephemeral_mount] = nil
      set[:rightimage][:fstab][:ephemeral_mount_opts] = nil
      set[:rightimage][:fstab][:ephemeral] = false
      set[:rightimage][:grub][:root_device] = "/dev/sda"
      set[:rightimage][:root_mount][:dump] = "1" 
      set[:rightimage][:root_mount][:fsck] = "1" 
    else
      raise "ERROR: unsupported hypervisor #{node[:rightimage][:hypervisor]} for cloudstack"
    end
end

# set rightscale stuff
set_unless[:rightimage][:rightlink_version] = ""

# generate command to install getsshkey init script 
case rightimage[:platform]
  when "ubuntu" 
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT update-rc.d getsshkey start 20 2 3 4 5 . stop 1 0 1 6 ."
  when "centos", "rhel"
    set[:rightimage][:getsshkey_cmd] = "chroot $GUEST_ROOT chkconfig --add getsshkey && \
               chroot $GUEST_ROOT chkconfig --level 4 getsshkey on"
end
