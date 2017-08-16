require 'rails_helper'

RSpec.describe 'Discourse Zendesk Plugin' do
  let(:topic) { Fabricate(:topic) }
  let(:admin) { Fabricate(:admin) }
  let(:staff) { Fabricate(:moderator) }
  let(:p1)    { Fabricate(:post, topic: topic) }

  describe 'Plugin Settings' do
    describe 'Storage Preparation' do
      let(:zendesk_url_default) { 'https://your-url.zendesk.com/api/v2' }
      let(:zendesk_enabled_default) { true }
      it 'has zendesk_url & zendesk_enabled site settings' do
        expect(SiteSetting.zendesk_url).to eq(zendesk_url_default)
        expect(SiteSetting.zendesk_enabled).to eq(zendesk_enabled_default)
      end
    end
    describe 'User Settings' do
      let(:new_zendesk_username) { 'new_zendesk_username' }
      let(:new_zendesk_token)    { 'new_token' }

      before do
        sign_in(staff)
      end
      it 'saves username and token' do
        xhr :post, '/zendesk-plugin/preferences', {
          zendesk: {
            username: new_zendesk_username,
            token: new_zendesk_token
          }
        }
        staff.reload
        expect(
          staff.custom_fields['discourse_zendesk_plugin_username'] +
          staff.custom_fields['discourse_zendesk_plugin_token']
        ).to eq(new_zendesk_username + new_zendesk_token)
      end
    end
  end
end
