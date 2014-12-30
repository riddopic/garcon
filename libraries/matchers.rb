# encoding: UTF-8

if defined?(ChefSpec)
  def download(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:download, :run, resource_name)
  end

  # Assert that a `zip_file` resource exists in the Chef run with the
  # action `:unzip`.
  #
  # @example Assert that a `zipfile` was unzipped
  #   expect(chef_run).to unzip_file_to('/tmp/path')
  #
  # @param [String, Regex] resource_name
  #   the name of the resource to match
  #
  # @return [ChefSpec::Matchers::ResourceMatcher]
  #
  def unzip_file_to(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:unzip, :unzip, resource_name)
  end

  # Assert that a `zip_file` resource exists in the Chef run with the
  # action `:zip`.
  #
  # @example Assert that a `zipfile` was zipped
  #   expect(chef_run).to zip_file_to('/tmp/file.zip')
  #
  # @param [String, Regex] resource_name
  #   the name of the resource to match
  #
  # @return [ChefSpec::Matchers::ResourceMatcher]
  #
  def zip_file_to(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:zip_file, :zip, resource_name)
  end
end
