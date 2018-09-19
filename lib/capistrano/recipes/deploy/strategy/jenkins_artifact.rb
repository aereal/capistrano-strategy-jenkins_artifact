require 'json'
require 'net/https'
require 'uri'

require 'capistrano/recipes/deploy/strategy/base'

class ::Capistrano::Deploy::Strategy::JenkinsArtifact < ::Capistrano::Deploy::Strategy::Base
  module ApiClient
    # jenkins_origin: URI
    # => Maybe[$parsed_body: Hash]
    def self.get_last_successful_build(jenkins_origin, dir_name)
      uri = jenkins_origin.clone
      uri.path += "/job/#{URI.encode_www_form_component(dir_name)}/lastSuccessfulBuild/api/json"
      req = Net::HTTP::Get.new(uri.path)
      res = Net::HTTP.start(uri.host, uri.port) {|session|
        session.use_ssl = uri.scheme == 'https'
        session.request(req)
      }
      case res
      when Net::HTTPSuccess
        if /\Aapplication\/json\b/ === (res.content_type || '')
          JSON.parse(res.body)
        end
      end
    end
  end

  module Helpers
    def self.get_artifact_url_by_build(build, &finder)
      finder ||= ->(_) { true }
      matched_artifact   = build['artifacts'].find(&finder)
      raise 'Specified artifact not found in current build !!' unless matched_artifact
      relative_build_path = matched_artifact['relativePath']
      jenkins_path          = build['url']
      artifact_path         = URI.escape("#{jenkins_path}artifact/#{relative_build_path}")
      return artifact_path
    end
  end

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

    release_name_from = fetch(:release_name_from, :build_at)
    if release_name_from != :build_at && release_name_from != :deploy_at
      abort ':release_name_from must be either `:build_at` or `:deploy_at`'
    end

    jenkins_origin = fetch(:jenkins_origin) or abort ":jenkins_origin configuration must be defined"
    last_successful_build = ApiClient.get_last_successful_build(jenkins_origin, dir_name)
    build_at = Time.at(last_successful_build['timestamp'] / 1000)

    set(:artifact_url) do
      artifact_finder = if exists?(:artifact_relative_path)
        ->(artifact) { artifact['relativePath'] == fetch(:artifact_relative_path) }
      elsif exists?(:artifact_display_path)
        ->(artifact) { artifact['displayPath'] == fetch(:artifact_display_path) }
      elsif exists?(:artifact_file_name)
        ->(artifact) { artifact['fileName'] == fetch(:artifact_file_name) }
      else
        ->(artifact) { true }
      end
      uri = Helpers.get_artifact_url_by_build(last_successful_build, &artifact_finder)
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

    if release_name_from == :build_at
      set(:release_name, build_at.strftime('%Y%m%d%H%M%S'))
    end
    set(:release_path, "#{fetch(:releases_path)}/#{fetch(:release_name)}")
    set(:latest_release, fetch(:release_path))

    run <<-SCRIPT
      mkdir -p #{fetch(:release_path)} && \
      (curl -s #{fetch(:artifact_url)} | \
      tar #{tar_opts.join(' ')} -C #{fetch(:release_path)} -#{compression_switch}xf -)
    SCRIPT
  end
end
