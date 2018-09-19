# Capistrano::Strategy::JenkinsArtifact [![Build Status][travis-badge]][travis-url] [![Gem Version](https://badge.fury.io/rb/capistrano-strategy-jenkins_artifact.svg)](https://badge.fury.io/rb/capistrano-strategy-jenkins_artifact)

Capistrano 2 strategy that uses Jenkins' artifact as a distribution provider.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'capistrano-strategy-jenkins_artifact'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-strategy-jenkins_artifact

## Usage

In your `Capfile` (`config/deploy.rb`, or `config/deploy/**/*.rb`):

### General job

```ruby
set :jenkins_origin, URI.parse('http://ci.example.com')
set :build_project, 'build-artifact-job'
set :deploy_via, :jenkins_artifact
```

### Multibranch job

```ruby
set :jenkins_origin, URI.parse('http://ci.example.com/job/multibranch-job')
set :is_multibranch_job, true
set :deploy_via, :jenkins_artifact
```

## Options

| name | type | required? | default value |
| ---- | ---- | --------- | ------------- |
| `jenkins_origin` | String | **Y** | N/A |
| `build_project` | String | **Y** | N/A |
| `is_multibranch_job` | Boolean | n | `nil` |
| `artifact_relative_path` | String | n | `nil` |
| `artifact_display_path` | String | n | `nil` |
| `artifact_file_name` | String | n | `nil` |
| `artifact_compression_type` | (see below) | n | guessed by artifact URL |
| `artifact_strip_level` | Numeric | n | `1` |
| `release_name_from` | (see below) | n | `:build_at` |

### Supported compression types

* gzip
* bzip2
* xz
* raw

### `release_name_from` option

You can set either `:build_at` (default) or `:deploy_at` to this option.

By default, this storategy will set release_name from the artifact's build timestamp.  This behavior is different from Capistrano's default.
If you prefer Capistrano's default behavior (use current timestamp for release_name), set this option to `:deploy_at`.

## Options exposed by capistrano-strategy-jenkins_artifact

| name | type |
| ---- | ---- |
| `artifact_url` | String |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aereal/capistrano-strategy-jenkins_artifact.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


[travis-url]: https://travis-ci.org/aereal/capistrano-strategy-jenkins_artifact
[travis-badge]: https://travis-ci.org/aereal/capistrano-strategy-jenkins_artifact.svg?branch=master
