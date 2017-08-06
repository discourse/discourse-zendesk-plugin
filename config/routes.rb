DiscourseZendeskPlugin::Engine.routes.draw do
  get "/some_long_url" => "topics#index"
end
