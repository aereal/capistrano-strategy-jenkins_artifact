require 'uri'

require 'capistrano/recipes/deploy/strategy/base'
require 'jenkins_api_client'

class ::JenkinsApi::Client::Job
  def self.get_artifact_url_by_build(build, &finder)
    finder ||= ->(_) { true }
    matched_artifact   = build['artifacts'].find(&finder)
    raise 'Specified artifact not found in current build !!' unless matched_artifact
    relative_build_path = matched_artifact['relativePath']
    jenkins_path          = build['url']
    artifact_path         = URI.escape("#{jenkins_path}artifact/#{relative_build_path}")
    return artifact_path
  end

  def get_last_successful_build(job_name)
    @logger.info "Obtaining last successful build number of #{job_name}"
    @client.api_get_request("/job/#{path_encode(job_name)}/lastSuccessfulBuild")
  end
end

class ::Capistrano::Deploy::Strategy::JenkinsArtifact < ::Capistrano::Deploy::Strategy::Base

  def _guess_compression_type(filename)
    case filename.downcase
    when /\.tar\.gz$/, /\.tgz$/
      :gzip
    when /\.tar\.bz2$/, /\.tbz$/
      :bzip2
    when /\.tar\.xz$/, /\.txz$/
      :xz
    when /\.tar$/
      :raw
    else
      :bzip2
    end
  end

  def _compression_type_to_switch(type)
    case type
    when :gzip  then 'z'
    when :bzip2 then 'j'
    when :xz    then 'J'
    when :raw   then '' # raw tarball
    else abort "Invalid compression type: #{type}"
    end
  end

  def deploy!
    dir_name = exists?(:is_multibranch_job) && fetch(:is_multibranch_job) ? fetch(:branch) : fetch(:build_project)

    jenkins_origin = fetch(:jenkins_origin) or abort ":jenkins_origin configuration must be defined"
    client = JenkinsApi::Client.new(server_url: jenkins_origin.to_s)

    last_successful_build = client.job.get_last_successful_build(dir_name)
    deploy_at = Time.at(last_successful_build['timestamp'] / 1000)

    set(:artifact_url) do
      artifact_finder = exists?(:artifact_relative_path) ?
        ->(artifact) { artifact['relativePath'] == fetch(:artifact_relative_path) } :
        ->(artifact) { true }
      uri = JenkinsApi::Client::Job.get_artifact_url_by_build(last_successful_build, &artifact_finder)
      abort "No artifact found for #{dir_name}" if uri.empty?
      URI.parse(uri).tap {|uri|
        uri.scheme = jenkins_origin.scheme
        uri.host = jenkins_origin.host
        uri.port = jenkins_origin.port
      }.to_s
    end

    compression_type = fetch(
      :artifact_compression_type,
      _guess_compression_type(fetch(:artifact_url))
    )
    compression_switch = _compression_type_to_switch(compression_type)

    tar_opts = []
    strip_level = fetch(:artifact_strip_level, 1)
    if strip_level && strip_level > 0
      tar_opts << "--strip-components=#{strip_level}"
    end

    set(:release_name, deploy_at.strftime('%Y%m%d%H%M%S'))
    set(:release_path, "#{fetch(:releases_path)}/#{fetch(:release_name)}")
    set(:latest_release, fetch(:release_path))

    run <<-SCRIPT
      mkdir -p #{fetch(:release_path)} && \
      (curl -s #{fetch(:artifact_url)} | \
      tar #{tar_opts.join(' ')} -C #{fetch(:release_path)} -#{compression_switch}xf -)
    SCRIPT
  end
end
