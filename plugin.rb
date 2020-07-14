# frozen_string_literal: true

# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)
# url: https://github.com/discourse/discourse-zendesk-plugin

# Require gems

gem 'inflection', '1.0.0'
gem 'mime-types-data', '3.2019.1009'
gem 'mime-types', '3.3'
gem 'zendesk_api', '1.26.0'

enabled_site_setting :zendesk_enabled
load File.expand_path('lib/discourse_zendesk_plugin/engine.rb', __dir__)

module ::DiscourseZendeskPlugin
  API_USERNAME_FIELD    = 'discourse_zendesk_plugin_username'
  API_TOKEN_FIELD       = 'discourse_zendesk_plugin_token'
  ZENDESK_URL_FIELD     = 'discourse_zendesk_plugin_zendesk_url'
  ZENDESK_API_URL_FIELD = 'discourse_zendesk_plugin_zendesk_api_url'
  ZENDESK_ID_FIELD      = 'discourse_zendesk_plugin_zendesk_id'
end

add_admin_route 'admin.zendesk.title', 'zendesk-plugin'
DiscoursePluginRegistry.serialized_current_user_fields << DiscourseZendeskPlugin::API_USERNAME_FIELD
DiscoursePluginRegistry.serialized_current_user_fields << DiscourseZendeskPlugin::API_TOKEN_FIELD

after_initialize do
  require_dependency File.expand_path('../lib/discourse_zendesk_plugin/helper.rb', __FILE__)
  require_dependency File.expand_path('../app/controllers/discourse_zendesk_plugin/zendesk_controller.rb', __FILE__)
  require_dependency File.expand_path('../app/controllers/discourse_zendesk_plugin/issues_controller.rb', __FILE__)
  require_dependency File.expand_path('../app/jobs/onceoff/migrate_zendesk_enabled_categories_site_settings.rb', __FILE__)
  require_dependency File.expand_path('../app/jobs/regular/zendesk_job.rb', __FILE__)

  add_to_serializer(:topic_view, ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym, false) do
    object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
  end

  add_to_serializer(:topic_view, ::DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym, false) do
    id = object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
    uri = URI.parse(SiteSetting.zendesk_url)
    "#{uri.scheme}://#{uri.host}/agent/tickets/#{id}"
  end

  add_to_serializer(:current_user, :discourse_zendesk_plugin_status) do
    object.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD].present? &&
      object.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD].present? &&
      SiteSetting.zendesk_url
  end

  require_dependency 'post'
  class ::Post
    after_commit :generate_zendesk_ticket, on: [:create]

    private

    def generate_zendesk_ticket
      return unless SiteSetting.zendesk_enabled?
      return unless DiscourseZendeskPlugin::Helper.category_enabled?(topic.category)
      Jobs.enqueue(:zendesk_job, post_id: id)
    end
  end

  require_dependency 'topic'
  class ::Topic
    after_update :publish_to_zendesk

    private

    def publish_to_zendesk
      return unless category_id_changed?

      old_category = Category.find(changes[:category_id].first)
      new_category = Category.find(changes[:category_id].last)

      old_cat_enabled = DiscourseZendeskPlugin::Helper.category_enabled?(old_category)
      new_cat_enabled = DiscourseZendeskPlugin::Helper.category_enabled?(new_category)

      # Do nothing if neither old or new category are enabled
      return nil if !old_cat_enabled && !new_cat_enabled

      # Do nothing if both categories are enabled
      return nil if old_cat_enabled && new_cat_enabled

      # enqueue job in future since after commit does not maintain changes hash
      Jobs.enqueue_in(5.seconds, :zendesk_job, topic_id: id)
    end
  end
end
