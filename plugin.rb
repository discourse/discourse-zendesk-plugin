# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)
# url: https://github.com/discourse/discourse-zendesk-plugin

# Require gems

gem 'inflection', '1.0.0'
gem 'zendesk_api', '1.14.4'

module ::DiscourseZendeskPlugin
  API_USERNAME_FIELD    = 'discourse_zendesk_plugin_username'
  API_TOKEN_FIELD       = 'discourse_zendesk_plugin_token'
  ZENDESK_URL_FIELD     = 'discourse_zendesk_plugin_zendesk_url'
  ZENDESK_API_URL_FIELD = 'discourse_zendesk_plugin_zendesk_api_url'
  ZENDESK_ID_FIELD      = 'discourse_zendesk_plugin_zendesk_id'
end

module ::DiscourseZendeskPlugin::Helper
  def zendesk_client
    client = ::ZendeskAPI::Client.new do |config|
      config.url      = SiteSetting.zendesk_url
      config.username = current_user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD]
      config.token    = current_user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]
    end
  end
end

Discourse::Application.routes.append do
  get '/admin/plugins/zendesk-plugin' => 'admin/plugins#index', constraints: ::StaffConstraint.new
  post '/zendesk-plugin/preferences' => 'discourse_zendesk_plugin/zendesk#preferences', constraints: ::StaffConstraint.new
  post '/zendesk-plugin/issues' => 'discourse_zendesk_plugin/issue#create', constraints: ::StaffConstraint.new
end

DiscoursePluginRegistry.serialized_current_user_fields << DiscourseZendeskPlugin::API_USERNAME_FIELD
DiscoursePluginRegistry.serialized_current_user_fields << DiscourseZendeskPlugin::API_TOKEN_FIELD

after_initialize do
  add_admin_route 'admin.zendesk.title', 'zendesk-plugin'
  add_to_serializer(:topic_view, ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym, false) {
    object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
  }
  add_to_serializer(:topic_view, ::DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym, false) {
    id = object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]

    uri = URI.parse(SiteSetting.zendesk_url)
    "#{uri.scheme}://#{uri.host}/agent/tickets/#{id}"
  }
  add_to_serializer(:current_user, :discourse_zendesk_plugin_status) {
    object.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD].present? &&
    object.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD].present? &&
    SiteSetting.zendesk_url
  }

  class ::DiscourseZendeskPlugin::ZendeskController < ::ApplicationController
    def preferences
      current_user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD] = params['zendesk']['username']
      current_user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]    = params['zendesk']['token']
      current_user.save
      render json: current_user
    end
  end

  class ::DiscourseZendeskPlugin::IssueController < ::ApplicationController
    include ::DiscourseZendeskPlugin::Helper
    def create
      topic_view         = ::TopicView.new(params[:topic_id], current_user)
      zendesk_topic = zendesk_client.tickets.create(
        subject: topic_view.topic.title,
        comment: { value: topic_view.topic.posts.first.raw },
        submitter_id: zendesk_client.current_user.id,
        priority: params['priority'] || 'urgent',
        custom_fields: [
          imported_from: ::Discourse.current_hostname,
          external_id: topic_view.topic.id ,
          imported_by: 'discourse_zendesk_plugin'
        ]
      )
      topic_view.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = zendesk_topic['id']
      topic_view.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_API_URL_FIELD] = zendesk_topic['url']
      topic_view.topic.save_custom_fields
      topic_view_serializer = ::TopicViewSerializer.new(
        topic_view,
        scope: topic_view.guardian,
        root: false)

      render_json_dump topic_view_serializer
    end
  end
end
