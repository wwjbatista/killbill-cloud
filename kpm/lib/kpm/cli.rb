# frozen_string_literal: true

require 'thor'

module KPM
  class Cli < Thor
    include KPM::Tasks
  end
end
