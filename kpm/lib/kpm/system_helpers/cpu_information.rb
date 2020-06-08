# frozen_string_literal: true

module KPM
  module SystemProxy
    class CpuInformation
      attr_reader :cpu_info, :labels

      def initialize
        @cpu_info = fetch
        @labels = [{ label: :cpu_detail },
                   { label: :value }]
      end

      private

      def fetch
        cpu_info = nil
        if OS.windows?
          cpu_info = fetch_windows
        elsif OS.linux?
          cpu_info = fetch_linux
        elsif OS.mac?
          cpu_info = fetch_mac
        end

        cpu_info
      end

      def fetch_linux
        cpu_data = `cat /proc/cpuinfo 2>&1`.gsub("\t", '')
        build_hash(cpu_data)
      end

      def fetch_mac
        cpu_data = `system_profiler SPHardwareDataType | grep -e "Processor" -e "Cores" -e "Cache" 2>&1`
        build_hash(cpu_data)
      end

      def fetch_windows
        cpu_name = `wmic cpu get Name`.split("\n\n")
        cpu_caption = `wmic cpu get Caption`.split("\n\n")
        cpu_max_clock_speed = `wmic cpu get MaxClockSpeed`.split("\n\n")
        cpu_device_id = `wmic cpu get DeviceId`.split("\n\n")
        cpu_status = `wmic cpu get Status`.split("\n\n")

        cpu = {}
        cpu[cpu_name[0].to_s.strip] = { cpu_detail: cpu_name[0].to_s.strip, value: cpu_name[1].to_s.strip }
        cpu[cpu_caption[0].to_s.strip] = { cpu_detail: cpu_caption[0].to_s.strip, value: cpu_caption[1].to_s.strip }
        cpu[cpu_max_clock_speed[0].to_s.strip] = { cpu_detail: cpu_max_clock_speed[0].to_s.strip, value: cpu_max_clock_speed[1].to_s.strip }
        cpu[cpu_device_id[0].to_s.strip] = { cpu_detail: cpu_device_id[0].to_s.strip, value: cpu_device_id[1].to_s.strip }
        cpu[cpu_status[0].to_s.strip] = { cpu_detail: cpu_status[0].to_s.strip, value: cpu_status[1].to_s.strip }

        cpu
      end

      def build_hash(data)
        cpu = {}
        return cpu if data.nil?

        data.split("\n").each do |info|
          infos = info.split(':')

          key = infos[0].to_s.strip
          next if key.empty? || key.eql?('flags')

          cpu[key] = { cpu_detail: key, value: infos[1].to_s.strip }
        end

        cpu
      end
    end
  end
end
