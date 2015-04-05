require 'chef/event_dispatch/base'
require 'chef/resource'
require 'chef/json_compat'
require 'serfx'

class Chef
  class Resource
    attr_reader :publish
    def publish(arg=nil)
      set_or_return(
        :publish,
        arg,
        :kind_of => [ TrueClass, FalseClass ]
      )
    end
  end
end

class Chef
  module EventDispatch
    class Serf < Chef::EventDispatch::Base

      def initialize(options = {})
        @subscribe = options.delete(:subscribe) || []
        @publish_all = options.delete(:publish_all) || false
        @ignore_failure = options.delete(:ignore_failure)
        @conn_opts = options.dup
      end

      def run_start(version)
        payload = payload_to_json(version: version)
        serf_event(__method__.to_s, payload)
      end

      def converge_complete
        serf_event(__method__.to_s, payload_to_json)
      end

      def resource_updated(res, action)
        if @publish_all or @subscribe.include?(res.to_s) or res.publish
          payload = payload_to_json(resource: res.to_s, action: action.to_s)
          serf_event(__method__.to_s, payload)
        end
      end

      def payload_to_json(data = {})
        Chef::JSONCompat.to_json(
          data.merge(node: Chef::Config[:node_name])
        )
      end

      def serf_event(*args)
        begin
          Serfx.connect(@conn_opts) do |conn|
            conn.event(*args)
          end
        rescue Errno::ECONNREFUSED => e
          if @ignore_failure
            Chef::Log.warn("Failed to publish event in serf: #{e.message}")
          else
            raise e
          end
        end
      end
    end
  end
end
