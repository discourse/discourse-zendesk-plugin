# frozen_string_literal: true

require 'rails_helper'
RSpec.describe DiscourseZendeskPlugin::SyncController do

  context "#webhook" do
    let!(:token) { "secrettoken" }
    let!(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.zendesk_enabled = true
      SiteSetting.sync_comments_from_zendesk = true
      SiteSetting.zendesk_incoming_webhook_token = token
    end

    it 'raises an error when the token is missing' do
      put "/zendesk-plugin/sync.json"
      expect(response.status).to eq(400)
    end

    it 'raises an error when the token is invalid' do
      put "/zendesk-plugin/sync.json", params: { token: "token" }
      expect(response.status).to eq(403)
    end

    it 'raises an error if the plugin is disabled' do
      SiteSetting.zendesk_enabled = false
      put '/zendesk-plugin/sync.json', params: { token: token }
      expect(response.status).to eq(422)
    end

    it 'raises an error if `sync_comments_from_zendesk` is disabled' do
      SiteSetting.sync_comments_from_zendesk = false
      put '/zendesk-plugin/sync.json', params: { token: token }
      expect(response.status).to eq(422)
    end

    it 'raises an error if required parameters are missing' do
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id }
      expect(response.status).to eq(400)
    end

    it 'raises an error when topic is not present' do
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: 24, ticket_id: 12 }
      expect(response.status).to eq(400)
    end

    it 'returns 204 when the request succeeds' do
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: 12 }
      expect(response.status).to eq(204)
    end

    context 'comments' do
      let(:ticket_id) { 12 }
      let(:comment_id) { 123 }
      let(:other_comment_id) { 567 }
      let(:private_comment_id) { 345 }
      let(:ticket_comments) { [] }
      let(:private_comment) do
        {
          "author_id": 123123,
          "body": "Thanks for your help! no attachments",
          "id": private_comment_id,
          "public": false,
          "type": "Comment"
        }
      end
      let(:comment_without_attachment) do
        {
          "author_id": 123123,
          "body": "Thanks for your help! no attachments",
          "id": other_comment_id,
          "public": true,
          "type": "Comment"
        }
      end
      let(:comment_with_attachment) do
        {
          "attachments": [
            {
              "content_type": "text/plain",
              "content_url": "https://company.zendesk.com/attachments/crash.log",
              "file_name": "crash.log",
              "id": 498483,
              "size": 2532,
              "thumbnails": []
            }
          ],
          "author_id": 123123,
          "body": "Thanks for your help!",
          "id": comment_id,
          "public": true,
          "type": "Comment"
        }
      end
      let(:comments_response_json) do
        {
          comments: ticket_comments
        }.to_json
      end
      before(:each) do
        DiscourseZendeskPlugin::Helper
          .expects(:category_enabled?)
          .with(topic.category_id)
          .returns(category_enabled)
          .at_least(0)

        stub_request(:get,
                     "https://your-url.zendesk.com/api/v2/tickets/#{ticket_id}/comments"
        ).to_return(status: 200,
                    body: comments_response_json,
                    headers: {
                      content_type: "application/json",
                    })
      end

      context 'without comment_id' do
        context 'category disabled' do
          let(:category_enabled) { false }
          it 'returns 204 when the request succeeds' do
            put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
            expect(response.status).to eq(204)
          end
        end
        context 'category enabled' do
          let(:category_enabled) { true }
          context 'no comments' do
            it 'returns 204 when the request succeeds' do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
              expect(response.status).to eq(204)
            end
            it "doesn't add a post" do
              expect do
                put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
              end.to_not change { topic.reload.posts.count }
            end
          end

          context 'with comments' do
            let(:ticket_comments) do
              [
                comment_with_attachment,
                comment_without_attachment,
                private_comment
              ]
            end
            it 'returns 204 when the request succeeds with comment_id' do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
              expect(response.status).to eq(204)
            end
            it "Adds a post" do
              expect do
                put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
              end.to change { topic.reload.posts.count }.from(0).to(1)
            end
            it "Adds correct comment post" do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id }
              expect(
                topic.reload.posts.last.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
              ).to eq other_comment_id.to_s
            end
          end
        end
      end

      context 'with comment_id' do
        context 'category disabled' do
          let(:category_enabled) { false }
          it 'returns 204 when the request succeeds with comment_id' do
            put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
            expect(response.status).to eq(204)
          end
        end
        context 'category enabled' do
          let(:category_enabled) { true }
          context 'no comments' do
            it 'returns 204 when the request succeeds with comment_id' do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
              expect(response.status).to eq(204)
            end
            it "doesn't add a post" do
              expect do
                put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
              end.to_not change { topic.reload.posts.count }
            end
          end

          context 'with comments' do
            let(:ticket_comments) do
              [
                private_comment,
                comment_with_attachment,
                comment_without_attachment
              ]
            end
            it 'returns 204 when the request succeeds with comment_id' do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
              expect(response.status).to eq(204)
            end
            it "Adds a post" do
              expect do
                put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
              end.to change { topic.reload.posts.count }.from(0).to(1)
            end
            it "Adds correct comment post" do
              put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: ticket_id, comment_id: comment_id }
              expect(
                topic.reload.posts.last.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
              ).to eq comment_id.to_s
            end
          end
        end
      end
    end
  end
end
