# frozen_string_literal: true

module DiscourseZendeskPlugin
  class Engine < ::Rails::Engine
    engine_name 'discourse-zendesk-plugin'
    isolate_namespace DiscourseZendeskPlugin

    config.after_initialize do
      Discourse::Application.routes.append do
        get '/admin/plugins/zendesk-plugin' => 'admin/plugins#index', constraints: ::StaffConstraint.new
        post '/zendesk-plugin/preferences' => 'discourse_zendesk_plugin/zendesk#preferences', constraints: StaffConstraint.new
        post '/zendesk-plugin/issues' => 'discourse_zendesk_plugin/issues#create', constraints: StaffConstraint.new
      end
    end
  end
end
