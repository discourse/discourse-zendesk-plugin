import { ajax } from "discourse/lib/ajax";
export default {
  zendesk_id: null,
  zendesk_url: null,
  dirty: false,

  setupComponent(args, component) {
    const zendesk_id = args.topic.get("discourse_zendesk_plugin_zendesk_id");

    if (zendesk_id && zendesk_id !== "") {
      component.set("zendesk_id", zendesk_id);
    }
    component.setProperties({
      zendesk_url: args.topic.get("discourse_zendesk_plugin_zendesk_url"),
      valid_zendesk_credential: component.get("currentUser.discourse_zendesk_plugin_status")
    });
  },

  actions: {
    createZendeskIssue() {
      let self = this;
      self.set("dirty", true);
      ajax("/zendesk-plugin/issues", {
        type: "POST",
        data: {
          topic_id: this.get("topic").get("id")
        }
      }).then(topic => {
        self.setProperties({
          zendesk_id: topic.discourse_zendesk_plugin_zendesk_id,
          zendesk_url: topic.discourse_zendesk_plugin_zendesk_url
        });
      });
    }
  }
};
