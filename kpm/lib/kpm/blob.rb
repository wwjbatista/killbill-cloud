# frozen_string_literal: true

module KPM
  class Blob
    def initialize(value, tmp_dir)
      @tmp_dir = tmp_dir
      @blob_file = @tmp_dir + File::SEPARATOR + rand.to_s
      store_value(value)
    end

    # On Macos systems, this will require defining a `secure_file_priv` config:
    #
    # e.g /usr/local/etc/my.cnf :
    # [mysqld]
    # ...
    # secure_file_priv=""
    def value
      "LOAD_FILE(\"#{@blob_file}\")"
    end

    private

    def store_value(value)
      File.open(@blob_file, 'wb') do |file|
        file.write(value)
      end
    end
  end
end
