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
end
