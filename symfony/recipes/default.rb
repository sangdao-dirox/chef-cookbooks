###Deploy
#
node[:deploy].each do |application, deploy|
    #create bin and vendor directory
    [ "#{deploy[:deploy_to]}/current/bin", "#{deploy[:deploy_to]}/current/vendor" ].each do |path|
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
        php composer.phar update
        EOH
    end

    # Symfony configuration 
    template "#{deploy[:deploy_to]}/current/app/config/parameters.yml" do
        source "parameters.yml.erb"
        mode 0644
        user "apache"
        group "apache"
        variables({
            :locale => deploy[:locale] || "en",
            :database_host => deploy[:database][:host] || "127.0.0.1",
            :database_port => deploy[:database][:port] || "null",
            :database_user => deploy[:database][:username] || "root",
            :database_password => deploy[:database][:password] || "evasion_pass",
            :database_database => deploy[:database][:database] || "evasion_main",
            :mailer_transport => deploy[:mail][:transport] || "smtp",
            :mailer_host => deploy[:mail][:host] || "127.0.0.1",
            :mailer_user => deploy[:mail][:username] || "null",
            :mailer_password => deploy[:mail][:password] || "null",
            :parameters => node[:custom_env], 
            :application => "#{application}",
            :secret => SecureRandom.base64 
        })
    end

    #enable write mode for cache, logs
    execute "run_allow_write_on_cache_and_logs" do
        command "chmod -R 777 app/cache app/logs"
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
        command "chmod -R 777 app/cache app/logs"
        cwd "#{deploy[:deploy_to]}/current"
        user "root"
        group "root"
    end
end
