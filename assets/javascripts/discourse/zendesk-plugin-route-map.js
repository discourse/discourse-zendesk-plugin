export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("zendesk-plugin");
  },
};
