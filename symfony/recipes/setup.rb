#Init dependency
#
#

%w{mcrypt php5-mcrypt php5-xsl mysql-server php5-mysql }.each do |p|
    package p do
        action :install
    end
end

#Enable the 
execute "enable php5enmod mcrypt" do
    command "php5enmod mcrypt"
    user "root"
    group "root"
end

