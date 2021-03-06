# Copyright (C) 2013 Cassiano Leal
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'net/https'

module DeployKeyCookbook
  module Helpers
    def auth(request)
      request.add_field 'User-Agent', 'Chef Deploy Key'
      request.add_field 'Content-Type', 'application/json'
      if new_resource.credentials[:token]
        request = add_token(request)
      elsif new_resource.credentials[:user] && new_resource.credentials[:password]
        request.basic_auth(new_resource.credentials[:user], new_resource.credentials[:password])
      else
        raise 'No credentials. Need API token or username/password combination.'
      end
      request
    end

    def request(req_type, url, body = nil)
      req = case req_type
            when :get    then Net::HTTP::Get.new(url.path)
            when :post   then Net::HTTP::Post.new(url.path)
            when :delete then Net::HTTP::Delete.new(url.path)
            end
      req = auth(req)
      req.body = body
      http = Net::HTTP.new(url.host, url.port)
      if url.instance_of? URI::HTTPS
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.request(req)
    end

    def add_key(label, key)
      body = {
          provider_specific_key_label() => "#{label} - #{node.name}",
          :key => key
        }.to_json
      response = request(:post, url, body)
      unless Net::HTTPOK      === response ||
             Net::HTTPCreated === response
        raise "Could not add SSH key #{new_resource.label} to repository: #{response.code} #{response.body}"
      end
      response
    end

    def remove_key(key)
      retrieved_key = get_key(key)
      key_url = url("/#{retrieved_key[retrieved_key_id()]}")
      response = request(:delete, key_url)
      unless Net::HTTPNoContent === response
        raise "Could not remove SSH key #{new_resource.label} from repository: #{response.code} #{response.body}"
      end
      response
    end

    def get_key(key)
      response = request(:get, url)
      unless Net::HTTPOK      === response ||
             Net::HTTPCreated === response
        raise "Could not get list of keys from repository: #{response.code} #{response.body}"
      end
      keys = JSON.parse response.body
      keys.find { |k| k['key'].strip == key.strip }
    end
  end
end

Chef::Resource.send(:include, DeployKeyCookbook::Helpers)
Chef::Provider.send(:include, DeployKeyCookbook::Helpers)
