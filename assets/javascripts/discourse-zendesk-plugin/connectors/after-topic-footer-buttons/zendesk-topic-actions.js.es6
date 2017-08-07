import { ajax } from 'discourse/lib/ajax'
import Discourse from 'discourse'
export default {
  zendesk_id: '',
  actions: {
    createZendeskIssue() {
      let self = this
      ajax('/zendesk-plugin/issues', {
        type: "POST",
        data: {
          topic_id: this.get('topic').get('id')
      }}).then((topic) => {
        self.set('zendesk_id', topic.discourse_zendesk_plugin_zendesk_id)
      })
    }
  },
  setupComponent(args, component) {
    let zendesk_id = args.topic.get('discourse_zendesk_plugin_zendesk_id')

    component.set('valid_zendesk_credential', Discourse.User.current().get('discourse_zendesk_plugin_status'))
    component.set('topic_id', args.topic.id)
    component.set('zendesk_url', args.topic.get('discourse_zendesk_plugin_zendesk_url'))
    if(zendesk_id && zendesk_id != '') {
      component.set('zendesk_id', zendesk_id)
    } else {
      component.set('zendesk_id', null)
    }
  }
}
