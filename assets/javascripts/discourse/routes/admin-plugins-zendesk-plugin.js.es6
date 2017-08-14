export default Discourse.Route.extend({
  model() {
  },
  setupController(controller, model) {
    let zendeskUrl
    if(!Discourse.SiteSettings.zendesk_url && Discourse.SiteSettings.zendesk_url != ''){
      zendeskUrl = null
    } else {
      zendeskUrl = Discourse.SiteSettings.zendesk_url
    }
    controller.setProperties({
      zendeskUsername: Discourse.User.current().get('custom_fields.discourse_zendesk_plugin_username'),
      zendeskToken: Discourse.User.current().get('custom_fields.discourse_zendesk_plugin_token'),
      zendeskUrl: zendeskUrl
    });
  }
});
