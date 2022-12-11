## Notes

A simple single-user ActivityPub server that should be somewhat compatible with
Mastodon, developed on top of
[sinatree](https://github.com/jcs/sinatree).

This is a work in progress.
It currently supports the following things:

- SQLite backend
- Simple queue daemon for making HTTP requests out-of-band
- Web display and pagination of local notes
- Importing of Twitter API JSON output
- Following remote users, responding to follow requests, broadcasting of new
  note creation
- Processing of foreign note creation, undos, forwards, etc.
- Local caching of remote avatars and image attachments
- HTTP request signing and verification of incoming signed requests (works with
  strict servers like GoToSocial)
- Enough of the Mastodon API implemented to have basic functionality with 3rd
  party clients like Metatext including web-based OAuth flow, image
  uploading/attaching; though many clients other than Metatext do not support
  API endpoints at subdirectories (`/notes/api/v1/...` instead of `/api/v1/...`)

It does not support the following things:

- Inline RsaSignature2017 verification (see
  [this](https://socialhub.activitypub.rocks/t/making-sense-of-rsasignature2017/347)
  and
  [this](https://gist.github.com/marnanel/ba6cba944d1f12d705891b1f7a7808d6))
- Tags
- Custom emoji
- Polls
- Web-based note creation
- Queue-based inbox
- Many of Mastodon's less-critical API endpoints like advanced searching,
  notifications, messages, bookmarks

### Usage

Clone `notes`:

	$ git clone https://github.com/jcs/notes.git

Then install Bundler dependencies:

	$ bundle install --path vendor/bundle

Initialize a session secret key:

	$ ruby -e 'require "securerandom"; print SecureRandom.hex(64)' > config/session_secret

Create a new database:

	$ env RACK_ENV=production bundle exec rake db:migrate

Create the single user:

	$ env RACK_ENV=production bin/console
	> u = User.new
	> u.username = "me"
	> u.password = u.password_confirmation = "OrpheanBeholderScryDoubt"
	> u.save
	=> true
	> u.contact.about = "Hello!"
	> u.contact.realname = "Fred"
	> u.contact.avatar_attachment = Attachment.build_from_url("https://example.com/images/my-avatar.jpg")
	> u.contact.avatar_attachment.save
	> u.contact.save!
	=> true

To override site settings, edit `config/app.rb`.

### License

Copyright (c) 2022 joshua stein `<jcs@jcs.org>`

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
