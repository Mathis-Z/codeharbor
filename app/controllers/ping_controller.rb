# frozen_string_literal: true

class PingController < ApplicationController
  before_action :postgres_connected!

  def index
    render json: {
      message: 'Pong',
      timenow_in_time_zone____: DateTime.now.in_time_zone.to_i,
      timenow_without_timezone: DateTime.now.to_i
    }
  end

  private

  def postgres_connected!
    # any unhandled exception leads to a HTTP 500 response.
    ApplicationRecord.establish_connection
    ApplicationRecord.connection
    raise ActiveRecord::ConnectionNotEstablished unless ApplicationRecord.connected?
  end
end
