# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)

add_admin_route 'admin.zendesk.title', 'zendesk-plugin'

Discourse::Application.routes.append do
  get '/admin/plugins/zendesk-plugin' => 'admin/plugins#index', constraints: AdminConstraint.new
  post '/zendesk-plugin/preferences' => 'discourse_zendesk_plugin/zendesk#preferences', constraints: StaffConstraint.new

end

after_initialize do
  module ::DiscourseZendeskPlugin
    API_USERNAME_FIELD = 'zendesk_plugin_username'
    API_TOKEN_FIELD    = 'zendesk_plugin_token'
  end
  class ::DiscourseZendeskPlugin::ZendeskController < ::ApplicationController
    def preferences
    end
  end
end
