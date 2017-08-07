import { ajax } from 'discourse/lib/ajax'
export default Ember.Controller.extend({
  zendeskUsername: '',
  zendeskToken: '',
  actions: {
    save() {
      ajax('/zendesk-plugin/preferences', {
        type: "POST",
        data: {
          zendesk: {
            username: this.get('zendeskUsername'),
            token: this.get('zendeskToken')
          }
      }});
    }
  }
});
