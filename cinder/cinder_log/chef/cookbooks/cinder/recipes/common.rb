# Copyright 2012 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Cookbook Name:: cinder
# Recipe:: common
#

file = File.open('/tmp/common_recipe.log', File::WRONLY | File::CREAT)
log = Logger.new(file)
log.level = Logger::WARN
log.warn("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
log.warn("COMMON.RB")

# get some passwords & addresses
admin_vip = node[:haproxy][:admin_ip]
public_vip = node[:haproxy][:public_ip]
server_root_password = node["percona"]["server_root_password"]

log.warn("server_root_password: " + server_root_password)
log.warn("admin_vip: " + admin_vip)
log.warn("public_vip: " + public_vip)

cinder_path = "/opt/cinder"
venv_path = node[:cinder][:use_virtualenv] ? "#{cinder_path}/.venv" : nil
venv_prefix = node[:cinder][:use_virtualenv] ? ". #{venv_path}/bin/activate &&" : nil

if node[:cinder][:use_gitrepo]

  pfs_and_install_deps "cinder" do
    wrap_bins [ "cinder-rootwrap" ]
    path cinder_path
    virtualenv venv_path
  end

  create_user_and_dirs "cinder" do
    user_name node[:cinder][:user]
  end

  execute "cp_policy.json_#{@cookbook_name}" do
    command "cp #{cinder_path}/etc/cinder/policy.json /etc/cinder/"
    creates "/etc/cinder/policy.json"
  end

  template "/etc/sudoers.d/cinder-rootwrap" do
    source "cinder-rootwrap.erb"
    mode 0440
    variables(:user => node[:cinder][:user])
  end

  bash "deploy_filters_#{@cookbook_name}" do
    cwd cinder_path
    code <<-EOH
    ### that was copied from devstack's stack.sh
    if [[ -d $CINDER_DIR/etc/cinder/rootwrap.d ]]; then
        # Wipe any existing rootwrap.d files first
        if [[ -d $CINDER_CONF_DIR/rootwrap.d ]]; then
            rm -rf $CINDER_CONF_DIR/rootwrap.d
        fi
        # Deploy filters to /etc/cinder/rootwrap.d
        mkdir -m 755 $CINDER_CONF_DIR/rootwrap.d
        cp $CINDER_DIR/etc/cinder/rootwrap.d/*.filters $CINDER_CONF_DIR/rootwrap.d
        chown -R root:root $CINDER_CONF_DIR/rootwrap.d
        chmod 644 $CINDER_CONF_DIR/rootwrap.d/*
        # Set up rootwrap.conf, pointing to /etc/cinder/rootwrap.d
        cp $CINDER_DIR/etc/cinder/rootwrap.conf $CINDER_CONF_DIR/
        sed -e "s:^filters_path=.*$:filters_path=$CINDER_CONF_DIR/rootwrap.d:" -i $CINDER_CONF_DIR/rootwrap.conf
        chown root:root $CINDER_CONF_DIR/rootwrap.conf
        chmod 0644 $CINDER_CONF_DIR/rootwrap.conf
    fi
    ### end
    EOH
    environment({
      'CINDER_DIR' => cinder_path,
      'CINDER_CONF_DIR' => '/etc/cinder'
    })
    not_if {File.exists?("/etc/cinder/rootwrap.d")}
  end
else
  package "cinder-common"
  package "python-mysqldb"
  package "python-cinder"
end

# Glance integration
#glance_env_filter = " AND glance_config_environment:glance-config-#{node[:cinder][:glance_instance]}"
#glance_servers = search(:node, "roles:glance-server#{glance_env_filter}") || []
#
#if glance_servers.length > 0
#  glance_server = glance_servers[0]
#  glance_server = node if glance_server.name == node.name
#  glance_server_ip = Chef::Recipe::Barclamp::Inventory.get_network_by_type(glance_server, "admin").address
#  glance_server_port = glance_server[:glance][:api][:bind_port]
#else
#  glance_server_ip = nil
#  glance_server_port = nil
#end
#Chef::Log.info("Glance server at #{glance_server_ip}")
# get a node list from the selected rabbitmq proposal
barclamp_name = "glance"
instance_var_name = "glance_instance"
begin
  proposal_name = "bc-" + barclamp_name + "-" + node["cinder"]["#{instance_var_name}"]
  proposal_databag = data_bag_item('crowbar', proposal_name)
  cont1_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][0]
  cont2_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][1]
  cont3_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][2]
  admin_network_databag = data_bag_item('crowbar', 'admin_network')
  cont1_admin_ip = admin_network_databag["allocated_by_name"]["#{cont1_name}"]["address"]
  cont2_admin_ip = admin_network_databag["allocated_by_name"]["#{cont2_name}"]["address"]
  cont3_admin_ip = admin_network_databag["allocated_by_name"]["#{cont3_name}"]["address"]
  
  # and construct a hosts string
  glance_api_port = ":" + node[:glance][:api][:bind_port].to_s
  glance_hosts_string = cont1_admin_ip + glance_api_port + "," + cont2_admin_ip + glance_api_port + "," + cont3_admin_ip + glance_api_port
rescue
  # if databag not found
  glance_hosts_string = nil
end

# Database integration (moved from database barclamp to Percona)
#sql_env_filter = " AND database_config_environment:database-config-#{node[:cinder][:database_instance]}"
#sqls = search(:node, "roles:database-server#{sql_env_filter}")
#if sqls.length > 0
#  sql = sqls[0]
#  sql = node if sql.name == node.name
#else
#  sql = node
#end

#sql_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(sql, "admin").address if sql_address.nil?
#Chef::Log.info("SQL server found at #{sql_address}")

# remove dependency on database barclamp
# at this point we know backend is percona (mysql) - JPA
backend_name = "mysql"
#include_recipe "database::client"
#backend_name = Chef::Recipe::Database::Util.get_backend_name(sql)
#include_recipe "#{backend_name}::client"
#include_recipe "#{backend_name}::python-client"

# use admin vip for sql connection string - JPA
#sql_connection = "#{backend_name}://#{node[:cinder][:db][:user]}:#{node[:cinder][:db][:password]}@#{sql_address}/#{node[:cinder][:db][:database]}"
sql_connection = "#{backend_name}://#{node[:cinder][:db][:user]}:#{node[:cinder][:db][:password]}@#{admin_vip}/#{node[:cinder][:db][:database]}"
log.warn("sql_connection: " + sql_connection)

my_ipaddress = Chef::Recipe::Barclamp::Inventory.get_network_by_type(node, "admin").address
node[:cinder][:api][:bind_host] = my_ipaddress

node[:cinder][:my_ip] = my_ipaddress
log.warn("my_ipaddress: " + my_ipaddress)

# RabbitMQ integration
#rabbitmq_env_filter = " AND rabbitmq_config_environment:rabbitmq-config-#{node[:cinder][:rabbitmq_instance]}"
#rabbits = search(:node, "roles:rabbitmq-default#{rabbitmq_env_filter}") || []
#if rabbits.length > 0
#  rabbit = rabbits[0]
#  rabbit = node if rabbit.name == node.name
#else
#  rabbit = node
#end

#rabbit_address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(rabbit, "admin").address
#Chef::Log.info("Rabbit server found at #{rabbit_address}")
# get a node list from the selected rabbitmq proposal
barclamp_name = "rabbitmq"
instance_var_name = "rabbitmq_instance"
begin
  proposal_name = "bc-" + barclamp_name + "-" + node["cinder"]["#{instance_var_name}"]
  proposal_databag = data_bag_item('crowbar', proposal_name)
  cont1_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][0]
  cont2_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][1]
  cont3_name = proposal_databag["deployment"]["#{barclamp_name}"]["elements"]["#{barclamp_name}"][2]
  admin_network_databag = data_bag_item('crowbar', 'admin_network')
  cont1_admin_ip = admin_network_databag["allocated_by_name"]["#{cont1_name}"]["address"]
  cont2_admin_ip = admin_network_databag["allocated_by_name"]["#{cont2_name}"]["address"]
  cont3_admin_ip = admin_network_databag["allocated_by_name"]["#{cont3_name}"]["address"]
  
  # and construct a hosts string
  rabbitmq_port = ":" + node[:rabbitmq][:port].to_s
  rabbit_hosts_string = cont1_admin_ip + rabbitmq_port + "," + cont2_admin_ip + rabbitmq_port + "," + cont3_admin_ip + rabbitmq_port

  rabbit_settings = {
  :hosts => rabbit_hosts_string,
  :user => node[:rabbitmq][:user],
  :password => node[:rabbitmq][:password],
  :vhost => node[:rabbitmq][:vhost]
  }
rescue
  # if databag not found
  rabbit_settings = nil
end

if node[:cinder][:volume][:volume_type] == "eqlx"
  Chef::Log.info("Pushing EQLX params to cinder.conf template")
  eqlx_params = node[:nova][:volume][:eqlx]
else
  eqlx_params = nil
end

if node[:cinder][:volume][:volume_type] == "eqlx"
  Chef::Log.info("Pushing EQLX params to cinder.conf template")
  eqlx_params = node[:nova][:volume][:eqlx]
else
  eqlx_params = nil
end

log.warn("glance_hosts_string: " + glance_hosts_string)
template "/etc/cinder/cinder.conf" do
  source "cinder.conf.erb"
  owner node[:cinder][:user]
  group "root"
  mode 0640
  variables(
            :eqlx_params => eqlx_params,
            :sql_connection => sql_connection,
            :rabbit_settings => rabbit_settings,
            :glance_server_ip => glance_hosts_string
            )
end

node.save
