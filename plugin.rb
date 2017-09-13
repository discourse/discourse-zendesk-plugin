# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)
# url: https://github.com/discourse/discourse-zendesk-plugin

# Require gems

gem 'inflection', '1.0.0'
gem 'zendesk_api', '1.14.4'

enabled_site_setting :zendesk_enabled

module ::DiscourseZendeskPlugin
  API_USERNAME_FIELD    = 'discourse_zendesk_plugin_username'
  API_TOKEN_FIELD       = 'discourse_zendesk_plugin_token'
  ZENDESK_URL_FIELD     = 'discourse_zendesk_plugin_zendesk_url'
  ZENDESK_API_URL_FIELD = 'discourse_zendesk_plugin_zendesk_api_url'
  ZENDESK_ID_FIELD      = 'discourse_zendesk_plugin_zendesk_id'
end

module ::DiscourseZendeskPlugin::Helper
  def zendesk_client(user=nil)
    client = ::ZendeskAPI::Client.new do |config|
      config.url      = SiteSetting.zendesk_url
      if user
        config.username = user.custom_fields[::DiscourseZendeskPlugin::API_USERNAME_FIELD]
        config.token    = user.custom_fields[::DiscourseZendeskPlugin::API_TOKEN_FIELD]
      else
        config.username = SiteSetting.zendesk_jobs_email
        config.token    = SiteSetting.zendesk_jobs_api_token
      end
    end
  end

  def self.category_enabled?(category)
    whitelist = SiteSetting.zendesk_enabled_categories.split('|')
    return whitelist.include?(category.name)
  end

  def latest_comment(ticket_id)
    ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
    last_public_comment = nil

    ticket.comments.all! do |comment|
      last_public_comment = comment if comment.public
    end
    last_public_comment
  end

  def update_topic_custom_fields(topic, ticket)
    topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = ticket['id']
    topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_API_URL_FIELD] = ticket['url']
    topic.save_custom_fields
  end
end

Discourse::Application.routes.append do
  get '/admin/plugins/zendesk-plugin' => 'admin/plugins#index', constraints: ::StaffConstraint.new
  post '/zendesk-plugin/preferences' => 'discourse_zendesk_plugin/zendesk#preferences', constraints: ::StaffConstraint.new
  post '/zendesk-plugin/issues' => 'discourse_zendesk_plugin/issue#create', constraints: ::StaffConstraint.new
  post '/zendesk-plugin/comments' => 'discourse_zendesk_plugin/comments#create'
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

      # Skipping creation if already created by category
      return if topic_view.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?

      ticket = zendesk_client(current_user).tickets.create(
        subject: topic_view.topic.title,
        comment: { value: topic_view.topic.posts.first.raw },
        submitter_id: zendesk_client(current_user).current_user.id,
        priority: params['priority'] || 'urgent',
        tags: SiteSetting.zendesk_tags.split('|'),
        custom_fields: [
          imported_from: ::Discourse.current_hostname,
          external_id: topic_view.topic.id ,
          imported_by: 'discourse_zendesk_plugin'
        ]
      )
      update_topic_custom_fields(topic_view.topic, ticket)
      topic_view_serializer = ::TopicViewSerializer.new(
        topic_view,
        scope: topic_view.guardian,
        root: false)

      render_json_dump topic_view_serializer
    end
  end
  class ::DiscourseZendeskPlugin::CommentsController < ::ApplicationController
    include ::DiscourseZendeskPlugin::Helper
    prepend_before_filter :verified_zendesk_enabled!
    prepend_before_filter :set_api_key_from_params
    skip_before_filter :verify_authenticity_token

    def create
      topic = Topic.find(params[:topic_id])
      ticket_id = topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]

      # Zendesk cannot send the latest comment.  It must be pulled from the api
      user = User.find_by_email(params[:email]) || current_user
      post = topic.posts.create!(
        user: user,
        raw: latest_comment(ticket_id).body
      )
      render json: {}, status: 204
    end

    private

    def set_api_key_from_params
      request.env[Auth::DefaultCurrentUserProvider::API_KEY] ||= params[:api_key]
    end

    def verified_zendesk_enabled!
      raise PluginDisabled unless SiteSetting.zendesk_sync_enabled?
    end
  end

  require_dependency 'jobs/base'
  module ::Jobs
    class ZendeskJob < Jobs::Base
      include ::DiscourseZendeskPlugin::Helper

      def execute(args)
        return unless SiteSetting.zendesk_enabled?
        post = Post.find(args[:post_id])

        return unless post.user_id > 0 # skip if post was made by system account
        return unless DiscourseZendeskPlugin::Helper.category_enabled?(post.topic.category)
        ticket_id = post.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]

        if ticket_id.present?
          add_comment(post, ticket_id)
        else
          create_ticket(post)
        end
      end

      private

      def create_ticket(post)
        ticket = zendesk_client.tickets.create(
          subject: post.topic.title,
          comment: { value: post.raw },
          submitter_id: fetch_submitter(post.user).id,
          priority: 'normal',
          tags: SiteSetting.zendesk_tags.split('|'),
          external_id: post.topic.id,
          custom_fields: [
            imported_from: ::Discourse.current_hostname,
            external_id: post.topic.id,
            imported_by: 'discourse_zendesk_plugin'
          ]
        )
        update_topic_custom_fields(post.topic, ticket)
      end

      def add_comment(post, ticket_id)
        ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
        ticket.comment = {
          body: post.raw,
          author_id: fetch_submitter(post.user).id
        }
        ticket.save
      end

      def fetch_submitter(user)
        result = zendesk_client.users.search(query: user.email)
        return result.first if result.size == 1
         zendesk_client.users.create(
          name: user.name || user.username,
          email: user.email
        )
      end
    end
  end


  require_dependency 'post'
  class ::Post
    after_create :generate_zendesk_ticket

    private

    def generate_zendesk_ticket
      return unless SiteSetting.zendesk_enabled?
      return unless DiscourseZendeskPlugin::Helper.category_enabled?(topic.category)

      # wait added to avoid ActiveRecord::RecordNotFound
      Jobs.enqueue_in(5.second, :zendesk_job, post_id: id)
    end
  end
end
