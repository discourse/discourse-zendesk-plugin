# frozen_string_literal: true

# name: discourse-zendesk-plugin
# about: Allows the creation of Zendesk tickets from Discourse topics.
# meta_topic_id: 68005
# version: 1.0.1
# authors: Yana Agun Siswanto, Arpit Jalan
# url: https://github.com/discourse/discourse-zendesk-plugin

gem "inflection", "1.0.0"

if Gem::Version.new(Faraday::VERSION) >= Gem::Version.new("2.0")
  gem "multipart-post", "2.2.3", require_name: "net/http/post/multipart"
  gem "faraday-multipart", "1.0.4", require_name: "faraday/multipart"
  gem "zendesk_api", "1.38.0.rc1"
end

enabled_site_setting :zendesk_enabled

module ::DiscourseZendeskPlugin
  PLUGIN_NAME = "discourse-zendesk-plugin"

  ZENDESK_ID_FIELD = "discourse_zendesk_plugin_zendesk_id"
  ZENDESK_URL_FIELD = "discourse_zendesk_plugin_zendesk_url"
  ZENDESK_API_URL_FIELD = "discourse_zendesk_plugin_zendesk_api_url"
end

require_relative "lib/discourse_zendesk_plugin/engine"
require_relative "lib/discourse_zendesk_plugin/helper"

after_initialize do
  require_relative "app/jobs/onceoff/migrate_zendesk_autogenerate_categories_site_settings"
  require_relative "app/jobs/regular/zendesk_job"
  require_relative "lib/discourse_zendesk_plugin/post_extension"
  require_relative "lib/discourse_zendesk_plugin/topic_extension"

  reloadable_patch do |plugin|
    Post.prepend DiscourseZendeskPlugin::PostExtension
    Topic.prepend DiscourseZendeskPlugin::TopicExtension
  end

  add_to_serializer(
    :topic_view,
    ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym,
    respect_plugin_enabled: false,
  ) { object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] }

  add_to_serializer(
    :topic_view,
    ::DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym,
    respect_plugin_enabled: false,
  ) do
    id = object.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
    uri = URI.parse(SiteSetting.zendesk_url)
    "#{uri.scheme}://#{uri.host}/agent/tickets/#{id}"
  end

  add_to_serializer(:current_user, :discourse_zendesk_plugin_status) do
    SiteSetting.zendesk_jobs_email.present? && SiteSetting.zendesk_jobs_api_token.present? &&
      SiteSetting.zendesk_url
  end
end
