import { ajax } from "discourse/lib/ajax";
export default {
  zendesk_id: "",
  dirty: false,
  actions: {
    createZendeskIssue() {
      let self = this;
      this.set("dirty", true);
      ajax("/zendesk-plugin/issues", {
        type: "POST",
        data: {
          topic_id: this.get("topic").get("id"),
        },
      }).then((topic) => {
        self.set("zendesk_id", topic.discourse_zendesk_plugin_zendesk_id);
        self.set("zendesk_url", topic.discourse_zendesk_plugin_zendesk_url);
        self.set("dirty", true);
      });
    },
  },
  setupComponent(args, component) {
    let zendesk_id = args.topic.get("discourse_zendesk_plugin_zendesk_id");

    component.set(
      "valid_zendesk_credential",
      component.get("currentUser.discourse_zendesk_plugin_status")
    );
    component.set("topic_id", args.topic.id);
    component.set(
      "zendesk_url",
      args.topic.get("discourse_zendesk_plugin_zendesk_url")
    );
    if (zendesk_id && zendesk_id !== "") {
      component.set("zendesk_id", zendesk_id);
    } else {
      component.set("zendesk_id", null);
    }
  },
};
