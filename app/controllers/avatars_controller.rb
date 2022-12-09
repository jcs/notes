class AvatarsController < ApplicationController
  self.path = "#{App.base_path}/avatars"

  DEFAULT_AVATAR = "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAQAAAAAYLlVAAAAtklEQVRo3u1ZWw6AMAwqxoN7c/w1Rl2dU7eW/S2+KIFSM9hiv67Jfl6zmRkLNyEyAwIgAAIwt3oRK3tIfwzA0Rk9le+vI6QG7jKFUAyw8hl0zwBfqv6MBbXi8VzABh/d6mDsTogLdR/t42cBK/QiG8Z3AQtTVg4XUCJM5QJvBsR2AYfXANK7gE4mUJj5t/scWeCdivRnFEcDT/NjPAbYuPo+GcBHlffLAA+Q68xIAAQgfhoiMwMrU+ctHbfyUzMAAAAASUVORK5CYII="

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
