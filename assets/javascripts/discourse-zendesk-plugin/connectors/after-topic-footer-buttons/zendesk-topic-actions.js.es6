import { ajax } from 'discourse/lib/ajax'
export default {
  actions: {
    createZendeskIssue() {
      ajax('/zendesk-plugin/issues', {
        type: "POST",
        data: {
          topic_id: this.get('topic').get('id')
      }})
    }
  },
  setupComponent(args, component) {
    console.log(args);
    component.set('topic_id', args.topic.id);
  }
}
