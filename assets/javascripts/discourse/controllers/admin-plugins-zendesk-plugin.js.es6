import { ajax } from 'discourse/lib/ajax'
export default Ember.Controller.extend({
  zendeskUsername: '',
  zendeskToken: '',
  actions: {
    save() {
      ajax
    }
  }
});
