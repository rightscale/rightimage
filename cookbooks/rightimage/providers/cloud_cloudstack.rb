class Chef::Resource
  include RightScale::RightImage::Helper
end

action :configure do
  bash "configure for cloudstack" do
    flags "-ex" 
    code <<-EOH
      guest_root=#{guest_root}

      case "#{node[:rightimage][:platform]}" in
      "ubuntu")
        case "#{node[:rightimage][:virtual_environment]}" in
        "xen")
          # enable console access
          cp $guest_root/etc/init/tty1.conf* $guest_root/etc/init/hvc0.conf
          sed -i "s/tty1/hvc0/g" $guest_root/etc/init/hvc0.conf
          echo "hvc0" >> $guest_root/etc/securetty

          for i in $guest_root/etc/init/tty*; do
            mv $i $i.disabled;
          done
          ;;
        "kvm"|"esxi")
          # Disable all ttys except for tty1 (console)
          for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
            mv $i $i.disabled;
          done
          ;;
        esac
      "centos"|"rhel")
        # clean out packages
        chroot $guest_root yum -y clean all

        # clean centos RPM data
        rm -rf ${guest_root}/var/lib/rpm/__*
        chroot $guest_root rpm --rebuilddb

        # configure dhcp timeout
        echo 'timeout 300;' > $guest_root/etc/dhclient.conf

        case "#{node[:rightimage][:virtual_environment]}" in
        "xen")
          # enable console access
          echo "2:2345:respawn:/sbin/mingetty xvc0" >> $guest_root/etc/inittab
          echo "xvc0" >> $guest_root/etc/securetty
          ;;
        "esxi")
          ;;
        "kvm")
          # following found on functioning CDC test image Centos 64bit using KVM hypervisor
          echo "alias scsi_hostadapter ata_piix"     > $guest_root/etc/modprobe.conf
          echo "alias scsi_hostadapter1 virtio_blk" >> $guest_root/etc/modprobe.conf
          echo "alias eth0 virtio_net"              >> $guest_root/etc/modprobe.conf

          # modprobe acpiphp at startup - required for CDC KVM hypervisor to detect attaching/detaching volumes
          echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local

          # enable console access
          echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
          echo "tty2" >> $guest_root/etc/securetty
          ;;
        esac
        ;;
      esac

      # set hwclock to UTC
      echo "UTC" >> $guest_root/etc/adjtime
    EOH
  end
end

action :upload do
  CDC_GEM_VER = "0.0.0"
  CDC_GEM = ::File.join(::File.dirname(__FILE__), "..", "files", "default", "right_vmops-#{CDC_GEM_VER}.gem")
  SANDBOX_BIN = "/opt/rightscale/sandbox/bin/gem"

  r = gem_package "nokogiri" do
    gem_binary SANDBOX_BIN
    version "1.4.3.1"
    action :nothing
  end
  r.run_action(:install)

  r = gem_package CDC_GEM do
    gem_binary SANDBOX_BIN
    version CDC_GEM_VER
    action :nothing
  end
  r.run_action(:install)

  Gem.clear_paths

  ruby_block "trigger download to test cloud" do
    block do
      require "rubygems"
      require "right_vmops"
      require "uri"

      name = "#{image_name}_#{node[:rightimage][:virtual_environment].upcase}"
      zoneId = node[:rightimage][:datacenter]

      case node[:rightimage][:platform]
      when "centos"
        if node[:rightimage][:release] == "5.4"
          osTypeId = 14 # CentOS 5.4 (64-bit)
        else
          osTypeId = 112 # CentOS 5.5 (64-bit)
        end
      when "ubuntu"
        osTypeId = 126 # Ubuntu 10.04 (64-bit)
      end
      
      case node[:rightimage][:virtual_environment]
      when "esxi"
        format = "OVA"
        hypervisor = "VMware"
        file_ext = "vmdk.ova"
      when "kvm"
        format = "QCOW2"
        hypervisor = "KVM"
        file_ext = "qcow2.bz2"
      when "xen"
        format = "VHD"
        hypervisor = "XenServer"
        file_ext = "vhd.bz2"
      end

      filename = "#{image_name}.#{image_file_ext}"
      local_file = "#{target_temp_root}/#{filename}"
      md5sum = Digest::MD5.hexdigest(::File.read(local_file))

      aws_url  = "rightscale-cloudstack-dev.s3.amazonaws.com"
      aws_path = s3_path_full
      image_url = "http://#{aws_url}/#{aws_path}/#{filename}"
      Chef::Log::info("Downloading from: #{image_url}...")
     
      Chef::Log.info("Registering image on cloud...")
      vmops = RightScale::VmopsFactory.right_vmops_class_for_version("2.2").new(node[:rightimage][:cloudstack][:cdc_api_key], node[:rightimage][:cloudstack][:cdc_secret_key], node[:rightimage][:cloudstack][:cdc_url])
      res = vmops.register_template(name, name, image_url, format, osTypeId, zoneId, hypervisor, md5sum, false, true)
      Chef::Log.info("Returned data: #{res.inspect}")

      image_id = res["registertemplateresponse"]["template"][0]["id"]

      $i=0
      $retries=60
      # Don't set less than 30 second polling period - It only updates every 30 seconds anyways.
      $wait=30

      until $i > $retries do
        info = vmops.list_templates(image_id,nil,"self")["listtemplatesresponse"]["template"][0]
        ready = info["isready"]
        status = info["status"]

        if ready == "true"
          Chef::Log.info("Image ready")
          break
        else
          $i += 1;
          if status =~ /expected/
            raise "Server returned error: #{status}"
          else
            Chef::Log.info("[#$i/#$retries] Image NOT ready! Status: #{status} Sleeping #$wait seconds...")
            sleep $wait unless $i > $retries
          end
        end
      end

      raise "Upload failed! Status: #{status}" unless ready == "true"

      # add to global id store for use by other recipes
      id_list = RightImage::IdList.new(Chef::Log)
      id_list.add(image_id)
    end
  end
end

