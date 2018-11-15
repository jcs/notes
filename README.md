## sinatree

A skeleton web application configured to use Sinatra and ActiveRecord with
some simple conventions:

- `views` directory set to `app/views/(current controller name)`

- default layout configured to `app/views/layouts/application.erb`, with
  per-controller layouts `app/views/layouts/(current controller name).erb`
  used first

- database tables using non-auto-incrementing IDs (see
[`UniqueId`](https://github.com/jcs/sinatree/blob/master/lib/unique_id.rb))

### Usage

Clone `sinatree`:

	$ git clone https://github.com/jcs/sinatree.git

Then install Bundler dependencies:

	$ bundle install --path vendor/bundle

Initialize a session secret key:

	$ ruby -e 'require "securerandom"; print SecureRandom.hex(64)' > config/session_secret

To create a database table `users` for a new `User` model:

	$ $EDITOR `bundle exec rake db:create_migration NAME=create_user_model`

	class CreateUserModel < ActiveRecord::Migration[5.2]
	  def change
	    create_table :users do |t|
	      t.timestamps
	      t.string :username
	      t.string :password_digest
	    end
	  end
	end

Then run the database migrations:

	$ bundle exec rake db:migrate

The new `User` model can be created as `app/models/user.rb`:

	class User < DBModel
	  has_secure_password
	end

A root controller can be created as `app/controllers/home_controller.rb`:

	class HomeController < ApplicationController
	  self.path = :root

	  get "/" do
	    "Hello, world"
	  end
	end

To run a web server with your application:

	$ bin/server

To access an IRB console:

	$ bin/console

### License

Copyright (c) 2017-2020 joshua stein `<jcs@jcs.org>`

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
