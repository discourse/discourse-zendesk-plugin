# frozen_string_literal: true

require 'rails_helper'

describe DiscourseZendeskPlugin::Helper do
  subject(:dummy) { Class.new { extend DiscourseZendeskPlugin::Helper } }

  it 'Instantiates' do
    expect(dummy).to be_present
  end

  describe 'comment_eligible_for_sync?' do
    let!(:topic_user) { Fabricate(:user) }
    let!(:other_user) { Fabricate(:user) }
    let(:post_user) { topic_user }
    let!(:topic) { Fabricate(:topic, user: topic_user) }
    let!(:post) { Fabricate(:post, topic: topic, user: post_user) }
    let(:zendesk_job_push_only_author_posts) { true }

    subject(:eligible) do
      dummy.comment_eligible_for_sync?(post)
    end

    before do
      SiteSetting.zendesk_job_push_only_author_posts = zendesk_job_push_only_author_posts
    end

    context 'zendesk_job_push_only_author_posts disabled' do
      let(:zendesk_job_push_only_author_posts) { false }

      context 'same author' do
        it 'should be true' do
          expect(eligible).to be_truthy
        end
      end

      context 'different author' do
        let(:post_user) { other_user }
        it 'should be true' do
          expect(eligible).to be_truthy
        end
      end
    end

    context 'zendesk_job_push_only_author_posts enabled' do
      let(:zendesk_job_push_only_author_posts) { true }

      context 'same author' do
        it 'should be true' do
          expect(eligible).to be_truthy
        end
      end

      context 'different author' do
        let(:post_user) { other_user }
        it 'should be false' do
          expect(eligible).to be_falsey
        end
      end
    end
  end

  describe 'build_raw_post_body' do
    before do
      SiteSetting.zendesk_append_attachments = zendesk_append_attachments
      comment.stubs(:body).returns(comment_body)
      comment.stubs(:html_body).returns(comment_html_body)
      comment.stubs(:attachments).returns(comment_attachments)
    end
    let(:comment) { mock('ZendeskAPI::Trackie') }
    let(:comment_body) { 'This is a test' }
    let(:comment_html_body) { '<p>This is a <a href="http://example.com/">test</a></p>' }
    let(:comment_attachments) { [] }
    subject(:body) { dummy.build_raw_post_body(comment) }
    context 'zendesk_append_attachments disabled' do
      let(:zendesk_append_attachments) { false }
      it 'uses comment body' do
        expect(body).to eq comment.body
      end
    end
    context 'zendesk_append_attachments enabled' do
      let(:zendesk_append_attachments) { true }
      it 'uses comment body' do
        expect(body).to eq comment.html_body
      end
      context 'has text attachment' do
        let(:text_file_attachment) do
          ZendeskAPI::Trackie.new(
            "content_type": "text/plain",
            "content_url": "https://company.zendesk.com/attachments/crash.log",
            "file_name": "crash.log",
            "id": 498483,
            "size": 2532,
          )
        end
        let(:comment_attachments) do
          [
            text_file_attachment
          ]
        end
        it 'appends attachments to comment html body' do
          expect(body).to start_with comment.html_body
          expect(body).to include "[crash.log (text/plain)](https://company.zendesk.com/attachments/crash.log)"
        end
        context 'and image thumbnail attachment' do
          let(:thumbnailed_attachment) do
            ZendeskAPI::Trackie.new(
              "content_type": "image/jpeg",
              "content_url": "https://example.zendesk.com/attachments/token/XXXX/,?name=happyday.jpeg",
              "deleted": false,
              "file_name": "happyday.jpeg",
              "height": 189,
              "id": 1261712928789,
              "inline": false,
              "mapped_content_url": "https://support.example.com/attachments/token/XXXX/?name=happyday.jpeg",
              "size": 5223,
              "url": "https://example.zendesk.com/api/v2/attachments/1234.json",
              "width": 267,
              "thumbnails": [
                {
                  "content_type": "image/jpeg",
                  "content_url": "https://example.zendesk.com/attachments/token/XXXX/,?name=happyday_thumb.jpeg",
                  "deleted": false,
                  "file_name": "happyday_thumb.jpeg",
                  "height": 57,
                  "id": 1261712928829,
                  "inline": false,
                  "mapped_content_url": "https://support.example.com/attachments/token/XXXX/,?name=happyday_thumb.jpeg",
                  "size": 1497,
                  "url": "https://example.zendesk.com/api/v2/attachments/1235.json",
                  "width": 80
                }
              ]
            )
          end
          let(:comment_attachments) do
            [
              text_file_attachment,
              thumbnailed_attachment
            ]
          end
          it 'appends attachments to comment html body' do
            expect(body).to start_with comment.html_body
            expect(body).to include "[crash.log (text/plain)](https://company.zendesk.com/attachments/crash.log)"
            expect(body).to include "[![](https://support.example.com/attachments/token/XXXX/,?name=happyday_thumb.jpeg)](https://support.example.com/attachments/token/XXXX/?name=happyday.jpeg)"
          end
        end
      end
    end
  end
end
