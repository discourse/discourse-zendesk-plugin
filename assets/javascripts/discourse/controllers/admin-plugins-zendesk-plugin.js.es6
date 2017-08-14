import { ajax } from 'discourse/lib/ajax'
export default Ember.Controller.extend({
  zendeskUsername: '',
  zendeskToken: '',
  zendeskUrl: '',
  dirty: false,
  notEmpty: Ember.computed('zendeskUsername', 'zendeskToken', function () {
    if(this.get('zendeskUsername') === '' && this.get('zendeskToken') === '')
      return false
    return true
  }),
  actions: {
    save() {
      this.set('dirty', true)
      ajax('/zendesk-plugin/preferences', {
        type: "POST",
        data: {
          zendesk: {
            username: this.get('zendeskUsername'),
            token: this.get('zendeskToken')
          }
      }}).then(() => {
        this.set('dirty', false)
      }).catch(function()  {
        bootbox.alert(I18n('admin.zendesk.general_error'))
      });
    },
    reset() {
      this.set('zendeskUsername', '')
      this.set('zendeskToken', '')
    }
  }
});
