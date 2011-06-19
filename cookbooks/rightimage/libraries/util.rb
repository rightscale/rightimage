module RightImage
  require 'fileutils'

  class Util
      
    DIRS = [ "/mnt", "/tmp" ]
    
    # Utility Class
    #
    # === Parameter
    # root_dir(File.path):: Root path of the image to be created    
    def initialize(root_dir, logger = nil)
      @log = (logger) ? logger : Logger.new(STDOUT)
      raise "ERROR: root_path must be a string" unless root_dir.is_a?(String)
      raise "ERROR: root_dir of `#{root_dir}` not found!" unless ::File.directory?(root_dir)
      @root = root_dir
    end
    
    def generate_persisted_passwd
      length = 14
      pw = nil
      filename = "/tmp/random_passwd"
      if ::File.exists?(filename)
        pw = File.open(filename, 'rb') { |f| f.read }
      else
        pw = Array.new(length/2) { rand(256) }.pack('C*').unpack('H*').first
        File.open(filename, 'w') {|f| f.write(pw) }
      end
      pw
    end
    
    # Cleaning up image
    #
    def sanitize()
      @log.info("Performing image sanitization routine...")
      DIRS.each do |dir|
        files = ::Dir.glob(::File.join(@root, dir, "**", "*"))
        @log.warn("Contents found in #{dir}!") unless files.empty?
        files.each do |f| 
          @log.warn("Deleting #{(::File.directory?(f))?"dir":"file"}: #{f}")
          FileUtils.rm_rf f         
        end
      end
      @log.info("Sanitize complete.")       
    end
   
  end

end

