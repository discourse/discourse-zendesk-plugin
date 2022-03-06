import Controller from "@ember/controller";
import { computed } from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";

export default Controller.extend({
  zendeskUsername: "",
  zendeskToken: "",
  zendeskUrl: "",
  dirty: false,

  notEmpty: computed("zendeskUsername", "zendeskToken", function () {
    if (this.get("zendeskUsername") === "" && this.get("zendeskToken") === "") {
      return false;
    }
    return true;
  }),

  actions: {
    save() {
      this.set("dirty", true);
      ajax("/zendesk-plugin/preferences", {
        type: "POST",
        data: {
          zendesk: {
            username: this.get("zendeskUsername"),
            token: this.get("zendeskToken"),
          },
        },
      })
        .then(() => {
          this.set("dirty", false);
        })
        .catch(function () {
          bootbox.alert(I18n("admin.zendesk.general_error"));
        });
    },
    reset() {
      this.set("zendeskUsername", "");
      this.set("zendeskToken", "");
    },
  },
});
