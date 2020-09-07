# frozen_string_literal: true

module DiscourseZendeskPlugin
  class Engine < ::Rails::Engine
    engine_name 'discourse-zendesk-plugin'
    isolate_namespace DiscourseZendeskPlugin

    config.after_initialize do
      Discourse::Application.routes.append do
        post '/zendesk-plugin/issues' => 'discourse_zendesk_plugin/issues#create', constraints: StaffConstraint.new
      end
    end
  end
end
