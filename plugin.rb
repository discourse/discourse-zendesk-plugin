# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)

# Require gems

gem 'inflection', '1.0.0'
gem 'zendesk_api', '1.14.4'
gem 'colorize', '0.8.1'
gem 'httplog', '0.99.7'

module ::DiscourseZendeskPlugin
  API_USERNAME_FIELD = 'discourse_zendesk_plugin_username'
  API_TOKEN_FIELD    = 'discourse_zendesk_plugin_token'
end

module ::DiscourseZendeskPlugin::Helper
  def zendesk_client
    client = ZendeskAPI::Client.new do |config|
      config.url      = SiteSetting.zendesk_url
      config.username = current_user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD]
      config.token    = current_user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]
    end
  end
end

Discourse::Application.routes.append do
  get '/admin/plugins/zendesk-plugin' => 'admin/plugins#index', constraints: AdminConstraint.new
  post '/zendesk-plugin/preferences' => 'discourse_zendesk_plugin/zendesk#preferences', constraints: StaffConstraint.new
  post '/zendesk-plugin/issues' => 'discourse_zendesk_plugin/issue#create', constraints: StaffConstraint.new
end


DiscoursePluginRegistry.serialized_current_user_fields << ::DiscourseZendeskPlugin::API_USERNAME_FIELD
DiscoursePluginRegistry.serialized_current_user_fields << ::DiscourseZendeskPlugin::API_TOKEN_FIELD

after_initialize do
  add_admin_route 'admin.zendesk.title', 'zendesk-plugin'
  # User.register_custom_field_type(::DiscourseZendeskPlugin::API_USERNAME_FIELD, :text)
  # User.register_custom_field_type(::DiscourseZendeskPlugin::API_TOKEN_FIELD, :text)

  class ::DiscourseZendeskPlugin::ZendeskController < ::ApplicationController
    def preferences
      current_user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD] = params['zendesk']['username']
      current_user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]    = params['zendesk']['token']
      current_user.save
      render json: current_user
    end
  end

  class ::DiscourseZendeskPlugin::IssueController < ::ApplicationController
    include DiscourseZendeskPlugin::Helper
    def create
      topic = ::Topic.find(params[:topic_id])
      zendesk_client.tickets.create(
        subject: topic.title,
        comment: { value: topic.posts.first.raw },
        submitter_id: zendesk_client.current_user.id,
        priority: params['priority'] || 'urgent',
        custom_fields: [
          imported_from: Discourse.current_hostname,
          external_id: topic.id ,
          imported_by: 'discourse_zendesk_plugin'
        ]
      )
      render json: topic
    end
  end
end
