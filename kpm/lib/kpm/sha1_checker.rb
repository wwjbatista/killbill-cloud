require 'logger'
require 'yaml'
require 'pathname'

module KPM
  class Sha1Checker

    def self.from_file(sha1_file, logger=nil)
      Sha1Checker.new(sha1_file, logger)
    end

    def initialize(sha1_file, logger=nil)
      @sha1_file = sha1_file
      init!

      if logger.nil?
        @logger       = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      else
        @logger = logger
      end
    end

    def sha1(coordinates)
      @sha1_config['sha1'][coordinates]
    end

    def all_sha1()
      @sha1_config['sha1']
    end

    def add_or_modify_entry!(coordinates, remote_sha1)
      @sha1_config['sha1'][coordinates] = remote_sha1
      save!
    end

    def remove_entry!(coordinates)
      @sha1_config['sha1'].delete(coordinates)
      save!
    end

    private

    def save!
      Dir.mktmpdir do |tmp_destination_dir|
        tmp_file = File.join(tmp_destination_dir, File.basename(@sha1_file))
        File.open(tmp_file, 'w') do |file|
          file.write(@sha1_config.to_yaml)
        end
        FileUtils.copy(tmp_file, @sha1_file)
      end
      reload!
    end

    def init!
      if !File.exists?(@sha1_file)
        create_sha1_directory_if_missing
        init_config = {}
        init_config['sha1'] = {}
        File.open(@sha1_file, 'w') do |file|
          file.write(init_config.to_yaml)
        end
      end
      reload!
    end

    def create_sha1_directory_if_missing
      sha1_dir = Pathname(@sha1_file).dirname
      if ! File.directory?(sha1_dir)
        FileUtils.mkdir_p(sha1_dir)
      end
    end

    def reload!
      @sha1_config = YAML::load_file(@sha1_file)
    end

  end
end
