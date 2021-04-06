# frozen_string_literal: true

module Dataverse

  class Error < StandardError
    def initialize(msg, backtrace: nil)
      @backtrace = backtrace
      super(msg)
    end

    def backtrace
      return @backtrace if @backtrace
      super
    end

    def cause
      nil
    end
  end

  class VersionError < Error
    def initialize(version)
      super "Version #{version} does not exist"
    end
  end

end
