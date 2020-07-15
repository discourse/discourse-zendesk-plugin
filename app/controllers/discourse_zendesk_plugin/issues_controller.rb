# frozen_string_literal: true

module DiscourseZendeskPlugin
  class IssuesController < ApplicationController
    include ::DiscourseZendeskPlugin::Helper

    def create
      topic = Topic.find(params[:topic_id])
      return if topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?

      create_ticket(topic.first_post)

      topic_view = ::TopicView.new(topic.id, current_user)
      topic_view_serializer = ::TopicViewSerializer.new(
        topic_view,
        scope: topic_view.guardian,
        root: false
      )
      render_json_dump topic_view_serializer
    end
  end
end
