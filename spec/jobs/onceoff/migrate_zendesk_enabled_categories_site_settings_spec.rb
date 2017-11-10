require 'rails_helper'

RSpec.describe Jobs::MigrateZendeskEnabledCategoriesSiteSettings do
  it 'should migrate the site settings correctly' do
    site_setting = SiteSetting.create!(
      name: 'zendesk_enabled_categories',
      data_type: SiteSettings::TypeSupervisor.types[:list]
    )

    described_class.new.execute_onceoff({})

    expect(site_setting.reload.data_type)
      .to eq(SiteSettings::TypeSupervisor.types[:category_list])
  end
end
