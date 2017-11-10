module Jobs
  class MigrateZendeskEnabledCategoriesSiteSettings < Jobs::Onceoff
    def execute_onceoff(_)
      site_setting = SiteSetting.where(
        name: 'zendesk_enabled_categories',
        data_type: SiteSettings::TypeSupervisor.types[:list]
      )

      return unless site_setting.exists?

      site_setting.first.update!(data_type: SiteSettings::TypeSupervisor.types[:category_list])
    end
  end
end
