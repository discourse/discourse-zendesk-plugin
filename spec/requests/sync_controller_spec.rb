# frozen_string_literal: true

require 'rails_helper'
RSpec.describe DiscourseZendeskPlugin::SyncController do

  context "#webhook" do
    let!(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.zendesk_enabled = true
      SiteSetting.sync_comments_from_zendesk = true
    end

    it 'raises an error if the plugin is disabled' do
      SiteSetting.zendesk_enabled = false
      put '/zendesk-plugin/sync.json'
      expect(response.status).to eq(422)
    end

    it 'raises an error if `sync_comments_from_zendesk` is disabled' do
      SiteSetting.sync_comments_from_zendesk = false
      put '/zendesk-plugin/sync.json'
      expect(response.status).to eq(422)
    end

    it 'raises an error if required parameters are missing' do
      put "/zendesk-plugin/sync.json", params: { topic_id: topic.id }
      expect(response.status).to eq(400)
    end

    it 'raises an error when topic is not present' do
      put "/zendesk-plugin/sync.json", params: { topic_id: 24, ticket_id: 12 }
      expect(response.status).to eq(400)
    end

    it 'returns 204 when the request succeeds' do
      put "/zendesk-plugin/sync.json", params: { topic_id: topic.id, ticket_id: 12 }
      expect(response.status).to eq(204)
    end
  end
end
