#
# Cookbook Name:: Symfony
# Recipe:: setup
#
# Copyright (C) 2015 Baldur Rensch
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'nscd'

include_recipe 'symfony::remi'
include_recipe 'symfony::remi-php55'

include_recipe 'php'

%w{php-pdo php-pgsql php-intl php-pecl-apcu php-mbstring php-opcache}.each do |p|
	package p do
		action :install
	end
end

include_recipe 'php-fpm'
php_fpm_pool 'www' do
	user "nginx"
	group "nobody"
	listen_owner "nginx"
	listen_group "nobody"
end

include_recipe 'nginx'
