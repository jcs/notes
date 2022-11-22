class RootController < ApplicationController
  self.path = :root

  get "/" do
    redirect "https://#{App.domain}/"
  end
end
