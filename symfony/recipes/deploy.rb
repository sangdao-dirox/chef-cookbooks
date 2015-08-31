#
# Cookbook Name:: Symfony
# Recipe:: deploy
#
# Copyright (C) 2015 Baldur Rensch
#
# All rights reserved - Do Not Redistribute
#

include_recipe "composer"

service "php-fpm" do
  service_name "php-fpm"
  supports :start => true, :stop => true, :restart => true, :reload => true
  action [ :nothing ]
end

require 'securerandom'

node[:deploy].each do |application, deploy|

    # Setup SSH key for checkouts
    prepare_git_checkouts(
        :user => deploy[:user],
        :group => deploy[:group],
        :home => deploy[:home],
        :ssh_key => deploy[:scm][:ssh_key]
    )
    Chef::Log.info(deploy.to_s)
    
    # Deploy code
    deploy "/srv/www/#{application}" do
        repo deploy[:scm][:repository]
        revision deploy[:scm][:revision]
        user deploy[:user]
        group deploy[:group]
        enable_submodules false
        shallow_clone false
        keep_releases deploy[:keep_releases]
        action :deploy
        symlinks({})
        symlink_before_migrate({})
        migrate false
    end

    # Composer 
    composer_package "/srv/www/#{application}/current" do
        action :install
        optimize_autoloader true
        prefer_source 'true'
        dev true
        verbose true
        user deploy[:user]
        group deploy[:group]
    end

    # Change user
    execute "chown_deploy_dir" do
        command "chown -R nginx:nobody /srv/www/#{application}/current/"
        user "root"
    end

    # Nginx Configuration
    template "/etc/nginx/conf.d/#{application}.conf" do
        source "nginx_conf.erb"
        owner "root"
        group "root"
        mode 0644
        action :create
        variables({
            :application => application,
            :dev => false,   # Make this configurable from node config
            :ssl_enabled => deploy['ssl_support']   
        })
        # notifies :reload, "service[nginx]"
    end

    # SSL Certificates
    file "/etc/nginx/#{application}.crt" do
        owner "root"
        group "root"
        mode "0755"
        action :create
        content deploy['ssl_certificate']
        only_if { deploy['ssl_support'] }
    end

    file "/etc/nginx/#{application}.key" do
        owner "root"
        group "root"
        mode "0755"
        action :create
        content deploy['ssl_certificate_key']
        only_if { deploy['ssl_support'] }
    end

    # Symfony configuration 
    template "#{deploy[:deploy_to]}/current/app/config/parameters.yml" do
        source "parameters.yml.erb"
        mode 0644
        user "nginx"
        group "nobody"
        variables({
            :host => (deploy[:database][:host] rescue nil),
            :user => (deploy[:database][:username] rescue nil),
            :password => (deploy[:database][:password] rescue nil),
            :database => (deploy[:database][:database] rescue nil),
            :parameters => (node[:custom_env] rescue nil), 
            :application => ("#{application}" rescue nil),
            :secret => SecureRandom.base64 
        })
    end

    # Post deploy commands (such as Asset Installs / Assetic)
    node[:post_deploy_symfony_commands].each do |cmd|
        execute "run_symfony_console_#{cmd}" do
            command "app/console #{cmd} --env=prod"
            cwd "#{deploy[:deploy_to]}/current"
            user "nginx"
            group "nobody"
        end
    end

    # Remove Dev Front Controller
    file "#{deploy[:deploy_to]}/current/web/app_dev.php" do
        action :delete
        notifies :reload, "service[php-fpm]", :immediately
    end

end
