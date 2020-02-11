# frozen_string_literal: true

# name: Discourse Zendesk Plugin
# about: Zendesk for Discourse
# authors: Yana Agun Siswanto (Inspired by shiv kumar's Zendesk-Plugin)
# url: https://github.com/discourse/discourse-zendesk-plugin

# Require gems

gem 'inflection', '1.0.0'
gem 'mime-types-data', '3.2019.1009'
gem 'mime-types', '3.3'
gem 'zendesk_api', '1.24.0'

enabled_site_setting :zendesk_enabled

module ::DiscourseZendeskPlugin
  API_USERNAME_FIELD    = 'discourse_zendesk_plugin_username'
  API_TOKEN_FIELD       = 'discourse_zendesk_plugin_token'
  ZENDESK_URL_FIELD     = 'discourse_zendesk_plugin_zendesk_url'
  ZENDESK_API_URL_FIELD = 'discourse_zendesk_plugin_zendesk_api_url'
  ZENDESK_ID_FIELD      = 'discourse_zendesk_plugin_zendesk_id'
end

module ::DiscourseZendeskPlugin::Helper
  def zendesk_client(user = nil)
    client = ::ZendeskAPI::Client.new do |config|
      config.url = SiteSetting.zendesk_url
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
    return false unless category

    whitelist = SiteSetting.zendesk_enabled_categories.split('|')
    whitelist.include?(category.id.to_s)
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

  def update_post_custom_fields(post, comment)
    return if comment.blank?
    post.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = comment['id']
    post.save_custom_fields
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
  load File.expand_path('app/jobs/onceoff/migrate_zendesk_enabled_categories_site_settings.rb', __dir__)

  add_admin_route 'admin.zendesk.title', 'zendesk-plugin'
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
      topic_view = ::TopicView.new(params[:topic_id], current_user)

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
          external_id: topic_view.topic.id,
          imported_by: 'discourse_zendesk_plugin'
        ]
      )
      update_topic_custom_fields(topic_view.topic, ticket)
      topic_view_serializer = ::TopicViewSerializer.new(
        topic_view,
        scope: topic_view.guardian,
        root: false
      )

      render_json_dump topic_view_serializer
    end
  end
  class ::DiscourseZendeskPlugin::CommentsController < ::ApplicationController
    include ::DiscourseZendeskPlugin::Helper
    prepend_before_action :verified_zendesk_enabled!
    prepend_before_action :set_api_key_from_params
    skip_before_action :verify_authenticity_token

    def create
      topic = Topic.find(params[:topic_id])
      ticket_id = topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]

      if DiscourseZendeskPlugin::Helper.category_enabled?(topic.category)
        # Zendesk cannot send the latest comment.  It must be pulled from the api
        user = User.find_by_email(params[:email]) || current_user
        comment = latest_comment(ticket_id)
        post_body = strip_signature(comment.body)
        post = topic.posts.new(
          user: user,
          raw: post_body
        )
        post.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = latest_comment(ticket_id).id
        post.save!
      end
      render json: {}, status: 204
    end

    private

    def strip_signature(content)
      return content if SiteSetting.zendesk_signature_regex.blank?

      result = Regexp.new(SiteSetting.zendesk_signature_regex).match(content)
      # when using match with an unamed group it returns /(.*)some_content/
      # the group result is returned as the second element in the MatchData
      result ? result[1] : content
    end

    def set_api_key_from_params
      request.env[Auth::DefaultCurrentUserProvider::API_KEY] ||= params[:api_key]
    end

    def verified_zendesk_enabled!
      raise PluginDisabled unless SiteSetting.zendesk_sync_enabled?
    end
  end

  require_dependency 'jobs/base'
  module ::Jobs
    class ZendeskJob < ::Jobs::Base
      sidekiq_options backtrace: true
      include ::DiscourseZendeskPlugin::Helper

      def execute(args)
        return unless SiteSetting.zendesk_enabled?
        return if SiteSetting.zendesk_jobs_email.blank? || SiteSetting.zendesk_jobs_api_token.blank?

        try_number = args.fetch(:try_number, 1)
        if args[:post_id].present?
          push_post!(args[:post_id], try_number)
        elsif args[:topic_id].present?
          push_topic!(args[:topic_id], try_number)
        end
      end

      private

      def push_topic!(topic_id, try_number)
        topic = Topic.find(topic_id)
        if DiscourseZendeskPlugin::Helper.category_enabled?(topic.category)
          topic.post_ids.each { |post_id| push_post!(post_id, try_number) }
        else
          ticket_id = topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
          ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
          zd_user = zendesk_client.users.search(query: SiteSetting.zendesk_jobs_email).first
          ticket.comment = {
            body: SiteSetting.zendesk_miscategorization_notice,
            author_id: zd_user.id,
            public: false
          }
          ticket.save
        end
      end

      def push_post!(post_id, try_number)
        post = Post.find(post_id)

        return unless post.user_id > 0 # skip if post was made by system account

        # skip if post has already been pushed to zendesk
        return if post.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?
        return unless DiscourseZendeskPlugin::Helper.category_enabled?(post.topic.category)

        ticket_id = post.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]

        if ticket_id.present?
          add_comment(post, ticket_id)
        else
          create_ticket(post, try_number)
        end
      end

      def create_ticket(post, try_number)
        return if try_number > 10

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

        # Retry later if the ticket cannot be created
        if ticket.nil?
          Jobs.enqueue_in(try_number.minutes, :zendesk_job, post_id: post.id, try_number: try_number + 1)
        else
          update_topic_custom_fields(post.topic, ticket)
          update_post_custom_fields(post, ticket.comments.first)
        end
      end

      def add_comment(post, ticket_id)
        return unless post.present? && post.user.present?

        ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
        ticket.comment = {
          body: post.raw,
          author_id: fetch_submitter(post.user).id
        }
        ticket.save
        update_post_custom_fields(post, ticket.comments.last)
      end

      def fetch_submitter(user)
        result = zendesk_client.users.search(query: user.email)
        return result.first if result.size == 1

        zendesk_client.users.create(
          name: (user.name.present? ? user.name : user.username),
          email: user.email,
          verified: true,
          role: 'end-user'
        )
      end
    end
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
