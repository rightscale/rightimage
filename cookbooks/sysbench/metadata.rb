maintainer       "RightScale, Inc"
maintainer_email "support@rightscale.com"
license          "Apache v2.0"
description      "Installs and runs sysbench"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"


# Use Opscode standard mysql
depends "mysql", "~> 3.0"

recipe "sysbench::default", "Install sysbench"
recipe "sysbench::run", "Run sysbench"

attribute "sysbench/result_file",
  :required => "recommended",
  :display_name => "Report Output Location",
  :description => "Where to output results of sysbench run. In json format.",
  :default => "/tmp/result.json"

attribute "sysbench/instance_type",
  :required => "required",
  :display_name => "Instance Type",
  :description => "Instance (or computer) type, for annotating the report. I.E. for an ec2 instance, m1.small."