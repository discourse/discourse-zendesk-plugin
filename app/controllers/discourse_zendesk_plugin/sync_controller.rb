# frozen_string_literal: true

module DiscourseZendeskPlugin
  class SyncController < ApplicationController
    include ::DiscourseZendeskPlugin::Helper
    layout false
    before_action :zendesk_token_valid?, only: :webhook
    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :webhook

    def webhook
      unless SiteSetting.zendesk_enabled? && SiteSetting.sync_comments_from_zendesk
        return render json: failed_json, status: 422
      end

      ticket_id = params[:ticket_id]
      raise Discourse::InvalidParameters.new(:ticket_id) if ticket_id.blank?
      topic = Topic.find_by_id(params[:topic_id])
      raise Discourse::InvalidParameters.new(:topic_id) if topic.blank?
      return if !DiscourseZendeskPlugin::Helper.category_enabled?(topic.category_id)

      user = User.find_by_email(params[:email]) || Discourse.system_user
      if params[:comment_id].present?
        comment = get_public_comment(ticket_id, params[:comment_id].to_i)
      else
        comment = get_latest_comment(ticket_id)
      end

      if comment.present?
        existing_comment = PostCustomField.where(name: ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD, value: comment.id).first

        unless existing_comment.present?
          post = topic.posts.create!(
            user: user,
            raw: build_raw_post_body(comment)
          )
          update_post_custom_fields(post, comment)
        end
      end

      render json: {}, status: 204
    end

    private

    def zendesk_token_valid?
      params.require(:token)

      if SiteSetting.zendesk_incoming_webhook_token.blank? ||
         SiteSetting.zendesk_incoming_webhook_token != params[:token]

        raise Discourse::InvalidAccess.new
      end
    end
  end
end
