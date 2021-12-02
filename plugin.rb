# frozen_string_literal: true

# name: discourse-zendesk-plugin
# about: Zendesk for Discourse
# version: 1.0.1
# authors: Yana Agun Siswanto, Arpit Jalan
# url: https://github.com/discourse/discourse-zendesk-plugin

gem 'inflection', '1.0.0'
gem 'discourse_zendesk_api'

enabled_site_setting :zendesk_enabled
load File.expand_path('lib/discourse_zendesk_plugin/engine.rb', __dir__)
load File.expand_path('lib/discourse_zendesk_plugin/helper.rb', __dir__)

module ::DiscourseZendeskPlugin
  ZENDESK_ID_FIELD = 'discourse_zendesk_plugin_zendesk_id'
  ZENDESK_URL_FIELD = 'discourse_zendesk_plugin_zendesk_url'
  ZENDESK_API_URL_FIELD = 'discourse_zendesk_plugin_zendesk_api_url'
end

after_initialize do
  require_dependency File.expand_path('../app/controllers/discourse_zendesk_plugin/issues_controller.rb', __FILE__)
  require_dependency File.expand_path('../app/controllers/discourse_zendesk_plugin/sync_controller.rb', __FILE__)
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
    SiteSetting.zendesk_jobs_email.present? &&
    SiteSetting.zendesk_jobs_api_token.present? &&
    SiteSetting.zendesk_url
  end

  require_dependency 'post'
  class ::Post
    after_commit :generate_zendesk_ticket, on: [:create]

    private

    def generate_zendesk_ticket
      return unless SiteSetting.zendesk_enabled?
      return unless DiscourseZendeskPlugin::Helper.category_enabled?(topic.category_id)
      Jobs.enqueue_in(5.seconds, :zendesk_job, post_id: id)
    end
  end

  require_dependency 'topic'
  class ::Topic
    after_update :publish_to_zendesk

    private

    def publish_to_zendesk
      return unless saved_changes[:category_id].present?

      old_category = Category.find_by(id: saved_changes[:category_id].first)
      new_category = Category.find_by(id: saved_changes[:category_id].last)

      old_cat_enabled = DiscourseZendeskPlugin::Helper.category_enabled?(old_category&.id)
      new_cat_enabled = DiscourseZendeskPlugin::Helper.category_enabled?(new_category&.id)

      # Do nothing if neither old or new category are enabled
      return nil if !old_cat_enabled && !new_cat_enabled

      # Do nothing if both categories are enabled
      return nil if old_cat_enabled && new_cat_enabled

      # enqueue job in future since after commit does not maintain changes hash
      Jobs.enqueue_in(5.seconds, :zendesk_job, topic_id: id)
    end
  end
end
