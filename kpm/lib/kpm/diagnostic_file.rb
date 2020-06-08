# frozen_string_literal: true

require 'yaml'
require 'tmpdir'
require 'zip'
require 'json'
require 'fileutils'
require 'date'

module KPM
  class DiagnosticFile
    # Temporary directory
    TMP_DIR_PREFIX = 'killbill-diagnostics-'
    TMP_DIR = Dir.mktmpdir(TMP_DIR_PREFIX)
    TMP_LOGS_DIR = TMP_DIR + File::Separator + 'logs'

    TENANT_FILE = 'tenant_config.data'
    SYSTEM_FILE = 'system_configuration.data'
    ACCOUNT_FILE = 'account.data'

    TODAY_DATE = Date.today.strftime('%m-%d-%y')
    ZIP_FILE = 'killbill-diagnostics-' + TODAY_DATE + '.zip'
    ZIP_LOG_FILE = 'logs.zip'

    def initialize(config_file = nil, killbill_api_credentials = nil, killbill_credentials = nil, killbill_url = nil,
                   database_name = nil, database_credentials = nil, database_host = nil, database_port = nil, kaui_web_path = nil,
                   killbill_web_path = nil, bundles_dir = nil, logger = nil)
      @killbill_api_credentials = killbill_api_credentials
      @killbill_credentials = killbill_credentials
      @killbill_url = killbill_url
      @database_name = database_name
      @database_credentials = database_credentials
      @database_host = database_host
      @database_port = database_port
      @config_file = config_file
      @kaui_web_path = kaui_web_path
      @killbill_web_path = killbill_web_path
      @logger = logger
      @original_logger_level = logger.level
      @catalina_base = nil
      @bundles_dir = bundles_dir
    end

    def export_data(account_id = nil, log_dir = nil)
      self.config = @config_file

      tenant_export_file = retrieve_tenant_config
      system_export_file = retrieve_system_config
      account_export_file = retrieve_account_data(account_id) unless account_id.nil?
      log_files = retrieve_log_files(log_dir)

      raise Interrupt, 'Account id or configuration file not found' unless File.exist?(system_export_file) && File.exist?(tenant_export_file)

      zip_file_name = TMP_DIR + File::Separator + ZIP_FILE

      Zip::File.open(zip_file_name, Zip::File::CREATE) do |zip_file|
        zip_file.add(TENANT_FILE, tenant_export_file)
        zip_file.add(SYSTEM_FILE, system_export_file)
        zip_file.add(ACCOUNT_FILE, account_export_file) unless account_id.nil?
        zip_file.add(ZIP_LOG_FILE, log_files) unless log_files.nil?
      end

      @logger.info "\e[32mDiagnostic data exported under #{zip_file_name} \e[0m"

      zip_file_name
    end

    # Private methods

    private

    def retrieve_tenant_config
      @logger.info 'Retrieving tenant configuration'
      # this suppress the message of where it put the account file, this is to avoid confusion
      @logger.level = Logger::WARN

      @killbill_api_credentials ||= [retrieve_config('killbill', 'api_key'), retrieve_config('killbill', 'api_secret')] unless @config_file.nil?
      @killbill_credentials ||= [retrieve_config('killbill', 'user'), retrieve_config('killbill', 'password')] unless @config_file.nil?
      @killbill_url ||= 'http://' + retrieve_config('killbill', 'host').to_s + ':' + retrieve_config('killbill', 'port').to_s unless @config_file.nil?

      tenant_config = KPM::TenantConfig.new(@killbill_api_credentials,
                                            @killbill_credentials,
                                            @killbill_url,
                                            @logger)
      export_file = tenant_config.export

      final = TMP_DIR + File::Separator + TENANT_FILE
      FileUtils.move(export_file, final)
      @logger.level = @original_logger_level

      final
    end

    def retrieve_system_config
      @logger.info 'Retrieving system configuration'
      system = KPM::System.new(@logger)
      export_data = system.information(@bundles_dir, true, @config_file, @kaui_web_path, @killbill_web_path)

      system_catalina_base(export_data)

      export_file = TMP_DIR + File::SEPARATOR + SYSTEM_FILE
      File.open(export_file, 'w') { |io| io.puts export_data }
      export_file
    end

    def retrieve_account_data(account_id)
      @logger.info 'Retrieving account data for id: ' + account_id
      # this suppress the message of where it put the account file, this is to avoid confusion
      @logger.level = Logger::WARN

      account = KPM::Account.new(@config_file, @killbill_api_credentials, @killbill_credentials,
                                 @killbill_url, @database_name,
                                 @database_credentials, @database_host, @database_port, nil, @logger)
      export_file = account.export_data(account_id)

      final = TMP_DIR + File::Separator + ACCOUNT_FILE
      FileUtils.move(export_file, final)
      @logger.level = @original_logger_level
      final
    end

    def retrieve_log_files(log_dir)
      if @catalina_base.nil? && log_dir.nil?
        @logger.warn "\e[91;1mUnable to find Tomcat process, logs won't be collected: make sure to run kpm using the same user as the Tomcat process or pass the option --log-dir\e[0m"
        return nil
      end

      @logger.info 'Collecting log files'
      log_base = log_dir || (@catalina_base + File::Separator + 'logs')
      log_items = Dir.glob(log_base + File::Separator + '*')

      zip_file_name = TMP_DIR + File::Separator + ZIP_LOG_FILE

      Zip::File.open(zip_file_name, Zip::File::CREATE) do |zip_file|
        log_items.each do |file|
          name = file.split('/').last
          zip_file.add(name, file)
        end
      end

      zip_file_name
    end

    # Helpers

    def system_catalina_base(export_data)
      @catalina_base = nil
      system_json = JSON.parse(export_data)

      return if system_json['java_system_information']['catalina.base'].nil?

      @catalina_base = system_json['java_system_information']['catalina.base']['value']
    end

    # Utils

    def retrieve_config(parent, child)
      item = nil

      unless @config.nil?

        config_parent = @config[parent]

        item = config_parent[child] unless config_parent.nil?

      end

      item
    end

    def config=(config_file = nil)
      @config = nil

      return if config_file.nil?

      @config = YAML.load_file(config_file) unless Dir[config_file][0].nil?
    end
  end
end
