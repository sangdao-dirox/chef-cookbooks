#Init dependency
#
#

%w{mcrypt php5-mcrypt php5-xsl}.each do |p|
    package p do
        action :install
    end
end

node[:deploy].each do |application, deploy|
    #create bin and vendor directory
    [ "#{deploy[:deploy_to]}/current/bin", "#{deploy[:deploy_to]}/current/vendor" ].each do |path|
        directory path do
            mode 0755
            owner 'root'
            group 'root'
            recursive true
            action :create
        end
    end

    #update composer
    script "install_composer" do
        interpreter "bash"
        user "root"
        cwd "#{deploy[:deploy_to]}/current"
        code <<-EOH
        curl -s https://getcomposer.org/installer | php
        php composer.phar update
        EOH
    end

    # Post deploy commands (such as Asset Installs / Assetic)
    node[:post_deploy_symfony_commands].each do |cmd|
        execute "run_symfony_console_#{cmd}" do
            command "php app/console #{cmd} --env=prod"
            cwd "#{deploy[:deploy_to]}/current"
            user "apache"
            group "apache"
        end
    end
end