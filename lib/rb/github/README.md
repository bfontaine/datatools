# ghrepo

Set your OAuth GitHub token in the `DATATOOLS_GH_TOKEN` environment variable
and run `bundle`.

Then:

```sh
bundle exec irb
```

```ruby
require "./ghrepo"

# Change the name as you want
r = Repo.new "Homebrew/homebrew"

File.write("homebrew.json", r.to_json)
```
