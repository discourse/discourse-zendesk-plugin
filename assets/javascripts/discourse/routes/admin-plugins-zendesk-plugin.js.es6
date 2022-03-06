import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";

export default DiscourseRoute.extend({
  model() {},

  setupController(controller) {
    let zendeskUrl;
    if (
      !this.siteSettings.zendesk_url &&
      this.siteSettings.zendesk_url !== ""
    ) {
      zendeskUrl = null;
    } else {
      zendeskUrl = this.siteSettings.zendesk_url;
    }
    controller.setProperties({
      zendeskUsername: User.current().get(
        "custom_fields.discourse_zendesk_plugin_username"
      ),
      zendeskToken: User.current().get(
        "custom_fields.discourse_zendesk_plugin_token"
      ),
      zendeskUrl,
    });
  },
});
