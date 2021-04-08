# frozen_string_literal: true

require "logger"
require_relative "lib/audit_logs"

def lambda_handler(event:, context:)
  logger.info "Lambda execution info: #{context.inspect}"
  AuditLogs.new().run
end
