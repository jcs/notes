class Following < DBModel
  belongs_to :user
  belongs_to :contact

  def unfollow!
    msg = {
      "@context" => ActivityStream::NS,
      "id" => "#{self.activitystream_actor}#undo-follow-#{Time.now.to_f}",
      "type" => "Undo",
      "actor" => self.user.activitystream_actor,
      "object" => self.follow_object,
    }

    res = ActivityStream.fetch(uri: self.contact["inbox"], method: :post,
      body: msg.to_json, signer: self.user)
    if !res.ok?
      return false, "not accepted: #{res.status}"
    end

    self.destroy
    return true, nil
  end
end
