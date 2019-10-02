# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::MigrateZendeskEnabledCategoriesSiteSettings do
  it 'should migrate the site settings correctly' do
    category = Fabricate(:category)
    category_2 = Fabricate(:category)

    site_setting = SiteSetting.create!(
      name: 'zendesk_enabled_categories',
      data_type: SiteSettings::TypeSupervisor.types[:list],
      value: "#{category.name}|#{category_2.name}|some random name"
    )

    described_class.new.execute_onceoff({})

    expect(site_setting.reload.data_type)
      .to eq(SiteSettings::TypeSupervisor.types[:category_list])

    expect(site_setting.value).to eq("#{category.id}|#{category_2.id}")
  end
end
