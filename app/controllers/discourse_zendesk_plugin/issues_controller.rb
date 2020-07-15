# frozen_string_literal: true

module DiscourseZendeskPlugin
  class IssuesController < ApplicationController
    include ::DiscourseZendeskPlugin::Helper

    def create
      topic_view = ::TopicView.new(params[:topic_id], current_user)
      topic = topic_view.topic
      return if topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?

      create_ticket(topic.first_post)
      topic_view_serializer = ::TopicViewSerializer.new(
        topic_view,
        scope: topic_view.guardian,
        root: false
      )
      render_json_dump topic_view_serializer
    end
  end
end
