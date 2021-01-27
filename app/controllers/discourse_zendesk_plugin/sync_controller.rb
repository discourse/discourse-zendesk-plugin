# frozen_string_literal: true

module DiscourseZendeskPlugin
  class SyncController < ApplicationController
    include ::DiscourseZendeskPlugin::Helper
    layout false
    before_action :set_api_key_from_params
    skip_before_action :check_xhr, :preload_json, :verify_authenticity_token, only: [:webhook]

    def webhook
      unless SiteSetting.zendesk_enabled? && SiteSetting.sync_comments_from_zendesk
        return render json: failed_json, status: 422
      end

      ticket_id = params[:ticket_id]
      raise Discourse::InvalidParameters.new(:ticket_id) if ticket_id.blank?
      topic = Topic.find_by_id(params[:topic_id])
      raise Discourse::InvalidParameters.new(:topic_id) if topic.blank?
      return if !DiscourseZendeskPlugin::Helper.category_enabled?(topic.category_id)

      user = User.find_by_email(params[:email]) || current_user
      latest_comment = get_latest_comment(ticket_id)
      if latest_comment.present?
        existing_comment = PostCustomField.where(name: ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD, value: latest_comment.id).first

        unless existing_comment.present?
          post = topic.posts.create!(
            user: user,
            raw: latest_comment.body
          )
          update_post_custom_fields(post, latest_comment)
        end
      end

      render json: {}, status: 204
    end

    private

    def set_api_key_from_params
      request.env[Auth::DefaultCurrentUserProvider::API_KEY] ||= params[:api_key]
    end
  end
end
