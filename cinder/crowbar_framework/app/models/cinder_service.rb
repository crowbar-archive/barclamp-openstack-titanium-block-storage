# Copyright 2012, Dell Inc. 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class CinderService < ServiceObject

  def initialize(thelogger)
    @bc_name = "cinder"
    @logger = thelogger
  end

  #if barclamp allows multiple proposals OVERRIDE
  # def self.allow_multiple_proposals?
# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "haproxy", "inst" => role.default_attributes[@bc_name]["haproxy_instance"] }
    answer << { "barclamp" => "percona", "inst" => role.default_attributes[@bc_name]["percona_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes[@bc_name]["keystone_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes[@bc_name]["rabbitmq_instance"] }
    answer << { "barclamp" => "glance", "inst" => role.default_attributes[@bc_name]["glance_instance"] }
    answer
  end
  
  def create_proposal
    @logger.debug("Cinder create_proposal: entering")
    base = super

    # HAProxy dependency
    base["attributes"][@bc_name]["haproxy_instance"] = ""
    begin
      haproxyService = HaproxyService.new(@logger)
      haproxys = haproxyService.list_active[1]
      if haproxys.empty?
        # No actives, look for proposals
        haproxys = haproxyService.proposals[1]
      end
      base["attributes"][@bc_name]["haproxy_instance"] = haproxys[0] unless haproxys.empty?
    rescue
      @logger.info("Cinder create_proposal: no haproxy found")
    end
    if base["attributes"][@bc_name]["haproxy_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "haproxy"))
    end

    # Percona dependency
    base["attributes"][@bc_name]["percona_instance"] = ""
    begin
      perconaService = PerconaService.new(@logger)
      perconas = perconaService.list_active[1]
      if perconas.empty?
        # No actives, look for proposals
        perconas = perconaService.proposals[1]
      end
      base["attributes"][@bc_name]["percona_instance"] = perconas[0] unless perconas.empty?
    rescue
      @logger.info("Cinder create_proposal: no percona found")
    end
    if base["attributes"][@bc_name]["percona_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "percona"))
    end

    # Keystone dependency
    base["attributes"][@bc_name]["keystone_instance"] = ""
    begin
      keystoneService = KeystoneService.new(@logger)
      keystones = keystoneService.list_active[1]
      if keystones.empty?
        # No actives, look for proposals
        keystones = keystoneService.proposals[1]
      end
      base["attributes"][@bc_name]["keystone_instance"] = keystones[0] unless keystones.empty?
    rescue
      @logger.info("Cinder create_proposal: no keystone found")
    end
    if base["attributes"][@bc_name]["keystone_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "keystone"))
    end

    # RabbitMQ dependency
    base["attributes"][@bc_name]["rabbitmq_instance"] = ""
    begin
      rabbitmqService = RabbitmqService.new(@logger)
      rabbitmqs = rabbitmqService.list_active[1]
      if rabbitmqs.empty?
        # No actives, look for proposals
        rabbitmqs = rabbitmqService.proposals[1]
      end
      base["attributes"][@bc_name]["rabbitmq_instance"] = rabbitmqs[0] unless rabbitmqs.empty?
    rescue
      @logger.info("Cinder create_proposal: no rabbitmq found")
    end
    if base["attributes"][@bc_name]["rabbitmq_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "rabbitmq"))
    end

    # Glance dependency
    base["attributes"][@bc_name]["glance_instance"] = ""
    begin
      glanceService = GlanceService.new(@logger)
      glances = glanceService.list_active[1]
      if glances.empty?
        # No actives, look for proposals
        glances = glanceService.proposals[1]
      end
      base["attributes"][@bc_name]["glance_instance"] = glances[0] unless glances.empty?
    rescue
      @logger.info("Cinder create_proposal: no glance found")
    end
    if base["attributes"][@bc_name]["glance_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "glance"))
    end

#    nodes = NodeObject.all
#    nodes.delete_if { |n| n.nil? or n.admin? }
#    if nodes.size >= 1
#      base["deployment"]["cinder"]["elements"] = {
#        "cinder-server" => [ nodes.first[:fqdn] ]
#      }
#    end

    base["attributes"]["cinder"]["service_password"] = '%012d' % rand(1e12)
    base["attributes"]["cinder"]["db"]["password"] = random_password

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

end

