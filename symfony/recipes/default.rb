###Deploy
#
node[:deploy].each do |application, deploy|
    #create bin and vendor directory
    #
    Chef::Log.info(application)
    Chef::Log.info(deploy)

    [ "#{deploy[:deploy_to]}/current/bin", "#{deploy[:deploy_to]}/current/vendor", "#{deploy[:deploy_to]}/current/web/js", "#{deploy[:deploy_to]}/current/web/css" ].each do |path|
        directory path do
            mode 0755
            owner 'root'
            group 'root'
            recursive true
            action :create
            not_if { ::File.exists?(path) }
        end
    end

    #update composer
    script "install_composer" do
        interpreter "bash"
        user "root"
        cwd "#{deploy[:deploy_to]}/current"
        code <<-EOH
        curl -s https://getcomposer.org/installer | php
        php composer.phar update --no-interaction
        EOH
    end

    # Symfony configuration 
    template "#{deploy[:deploy_to]}/current/app/config/parameters.yml" do
        source "parameters.yml.erb"
        mode 0644
        variables({
            :locale => deploy[:locale] || "en",
            :database_host => (deploy[:database][:host] rescue nil),
            :database_port => (deploy[:database][:port] rescue nil),
            :database_user => (deploy[:database][:username] rescue nil),
            :database_password => (deploy[:database][:password] rescue nil),
            :database_name => (deploy[:database][:database] rescue nil),
            :mailer_transport => (deploy[:mail][:transport] rescue nil),
            :mailer_host => (deploy[:mail][:host] rescue nil),
            :mailer_user => (deploy[:mail][:username] rescue nil),
            :mailer_password => (deploy[:mail][:password] rescue nil),
            :parameters => (deploy[:custom_env] rescue nil), 
            :application => "#{application}",
            :secret => SecureRandom.base64 
        })
    end

    #enable write mode for cache, logs
    execute "run_allow_write_on_cache_and_logs" do
        command "chmod -R 0777 app/cache app/logs"
        cwd "#{deploy[:deploy_to]}/current"
        user "root"
        group "root"
    end

    # Post deploy commands
    deploy[:post_deploy_symfony_commands].each do |cmd|
        execute "run_symfony_console_#{cmd}" do
            command "php app/console #{cmd} --env=prod"
            cwd "#{deploy[:deploy_to]}/current" 
        end
    end
    
    #enable write mode for cache, logs
    execute "run_allow_write_on_cache_and_logs" do
        command "chmod -R 0777 app/cache app/logs"
        cwd "#{deploy[:deploy_to]}/current"
        user "root"
        group "root"
    end
end
