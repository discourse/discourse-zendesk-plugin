# frozen_string_literal: true

module DiscourseZendeskPlugin
  class ZendeskController < ApplicationController
    def preferences
      current_user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD] = params['zendesk']['username']
      current_user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]    = params['zendesk']['token']
      current_user.save
      render json: current_user
    end
  end
end
