class AvatarsController < ApplicationController
  self.path = "#{App.base_path}/avatars"

  DEFAULT_AVATAR = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABAAQMAAACQp+OdAAAABlBMVEUAAAD///+l2Z/dAAAAaklEQVQoz63RwQmAMAwF0ECvhYzU1bOBqzhA4BsVJb8VKmgufYekkB+RoRrsNygIzQRYGQVwhgLIgLWATRBv/JjhtSpj7HmcWhjvpqxD37NvzHDxUpSBc50pJCOSO6K7IWcqCX4d9xuG2gAIUwjcjcJ9hQAAAABJRU5ErkJggg=="

  get "/:address" do
    c = Contact.where(:address => params[:address]).first
    if c && c.avatar
      content_type c.avatar.type
      return c.avatar.blob.data
    end

    content_type "image/png"
    Base64.decode64(DEFAULT_AVATAR)
  end
end
