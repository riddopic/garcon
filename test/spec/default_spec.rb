# Encoding: utf-8

require_relative 'spec_helper'

# this will pass on templatestack, fail elsewhere, forcing you to
# write those chefspec tests you always were avoiding
describe 'garcon::development' do
  before { stub_resources }
  supported_platforms.each do |platform, versions|
    versions.each do |version|
      context "on #{platform.capitalize} #{version}" do
        let(:chef_run) do
          ChefSpec::Runner.new(platform: platform, version: version) do |node|
            node_resources(node)
          end.converge(described_recipe)
        end

        specify do
          expect(chef_run).to include_recipe 'chef_handler::default'
        end


      end
    end
  end
end


describe 'my_chef_handlers::default' do
  handler_path = File.join('files', 'default')

  let(:chef_run) do
    chef_runner = ChefSpec::Runner.new do |node|
      node.set['chef_handler']['handler_path'] = handler_path
      node.set['statsd']['server'] = '127.0.0.1'
    end
    chef_runner.converge 'my_chef_handlers::default'
  end

end
