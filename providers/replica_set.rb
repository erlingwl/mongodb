#
# Cookbook Name:: hipsnip-mongodb
# Provider:: replica_set
#
# Copyright 2013, HipSnip Ltd.
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

action :create do
  members = new_resource.members
  seed_list = members.collect{|n| n['host']}
  replica_set_name = new_resource.replica_set

  Chef::Log.info "Configuring replica set with #{members.length} member(s)"

  # Some basic validation

  raise "You have to pass in at least one member" if members.empty?

  unless (non_hash_members = members.reject{|n| n.is_a?(Hash)}).empty?
    raise "Some of the member configuations are not hashes:\n#{non_hash_members.inspect}"
  end

  unless (incomplete_members = members.reject{|n| n.key?('id') && n.key?('host')}).empty?
    raise "Some of the members are missing an 'id' or 'host' key:\n#{incomplete_members.inspect}"
  end

  unless (invalid_hosts = members.reject{|n| n['host'] =~ /^[a-z0-9\-\.]+:\d+$/}).empty?
    raise "Some of the member 'host' settings are the wrong format:\n#{invalid_hosts.inspect}"
  end
  
end


################################################################################
# Helpers

def wait_for_successful_status(connection, retries = 10)
  begin
    repl_status = connection['admin'].command({'replSetGetStatus' => 1})
  rescue Mongo::OperationFailure => ex
    Chef::Log.warn "Waiting for successful status #{retries}"
    sleep 5
    wait_for_successful_status(connection, retries - 1) if retries > 0
  end
end

def generate_member_config(node)
  member_config = ::BSON::OrderedHash.new
  member_config['_id'] = node['id']
  member_config['host'] = node['host']

  # Only add extra properties if they were changed from their defaults
  member_config['buildIndexes'] = node['build_indexes'] unless node['build_indexes'].nil? || node['build_indexes'] == true
  member_config['priority'] = node['priority'] unless node['priority'].nil? || node['priority'] == 1.0
  member_config['arbiterOnly'] = node['arbiter_only'] unless node['arbiter_only'].nil? || node['arbiter_only'] == false
  member_config['slaveDelay'] = node['slave_delay'] unless node['slave_delay'].nil? || node['slave_delay'] == 0
  member_config['hidden'] = node['hidden'] unless node['hidden'].nil? || node['hidden'] == false
  member_config['votes'] = node['votes'] unless node['votes'].nil? || node['votes'] == 1
  member_config['tags'] = node['tags'] unless node['tags'].nil? || node['tags'].empty?

  member_config
end