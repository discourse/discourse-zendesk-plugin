import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";

export default DiscourseRoute.extend({
  model() {},
  setupController(controller) {
    let zendeskUrl;
    if (
      !Discourse.SiteSettings.zendesk_url &&
      Discourse.SiteSettings.zendesk_url !== ""
    ) {
      zendeskUrl = null;
    } else {
      zendeskUrl = Discourse.SiteSettings.zendesk_url;
    }
    controller.setProperties({
      zendeskUsername: User.current().get(
        "custom_fields.discourse_zendesk_plugin_username"
      ),
      zendeskToken: User.current().get(
        "custom_fields.discourse_zendesk_plugin_token"
      ),
      zendeskUrl: zendeskUrl,
    });
  },
});
