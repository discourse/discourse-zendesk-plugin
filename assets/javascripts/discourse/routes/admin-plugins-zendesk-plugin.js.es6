export default Discourse.Route.extend({
  model() {
  },
  setupController(controller, model) {
    controller.setProperties({
      zendeskUsername: this.get('currentUser').custom_fields['discourse_zendesk_plugin_username'],
      zendeskToken: this.get('currentUser').custom_fields['discourse_zendesk_plugin_token']
    });
  }
});
