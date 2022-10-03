# Schnecke

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/prschmid/schnecke/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/prschmid/schnecke/tree/main)

A very simple gem to enable ActiveRecord models to have slugs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'schnecke'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install schnecke

## Usage

Given a class `SomeObject` which has the attribute `name` and has a `slug` column defined, we can do the following:

```ruby
class SomeObject
  include Schnecke
  slug :name
end
```

This will take the value in `name` and automatically set the slug based on it. If the slug needs to be based on multiple attributes of a model, simply pass in the array of attributes as follows:

```ruby
class SomeObject
  include Schnecke
  slug [:first_name, :last_name]
end
```

Under the hood, this library adds a `before_validate` callback that automatically runs a method called `assign_slug`. You are welcome to call this method explicity if you so desire.

```
obj = SomeObject.new(name: 'Hello World!')
obj.assign_slug
```

It is important to note that if the attribute used to hold the slug (`slug` by default, see next section) already contains a value, the slug assignment **WILL NOT HAPPEN**. This means, if you manually assign the slug by explicitly setting the slug value yourself, it will not be modified. If you would like the slug to be overwrriten you can call the `reassign_slug` method.

```
obj = SomeObject.new(name: 'Hello World!', slug: 'hi')

# This will do nothing as the slug was already set
obj.assign_slug

# This will cause the slug to be assigned
obj.reassign_slug
```

### Slug column

By default it is assumed that the generated slug will be assigned to the `slug` attribute of the model. If one needs to place the slug in a different columm, this can be done by defining the `column` attribute:

```ruby
class SomeObject
  include Schnecke
  slug :name, column: :some_other_column
end
```

The above will place the generated slug in `some_other_column`.

### Setting the maximum length of a slug

By default the maxium length of a slug is 32 characters *NOT INCLUDING* any potential sequence numbers added to make it unique (see the "Handling non-unique slugs" section). You can either change the maximum or remove it entirely as follows


```ruby
class SomeObject
  include Schnecke
  slug :name, limit_length: 15
end
```

```ruby
class SomeObject
  include Schnecke
  slug :name, limit_length: false
end
```

### Slug Uniquness

By default slugs are unique to the object that defines the slug. For example if we have the 2 objects, `SomeObject` and `SomeOtherObject` as defined as below, then the slugs will be unique for all slugs for all type `SomeObject` objcets and all type `SomeOtherObject` objects. 

```ruby
class SomeObject
  include Schnecke
  slug :name
end

class SomeOtherObject
  include Schnecke
  slug :name
end
```

This means that the slug `foo` can exists 2 times; once for any object of type `SomeObject` and once for any object of type `SomeOtherObject`. Currently there is no way to create globally unique slugs. If this is something that is required, then something like [`friendly_id`](https://github.com/norman/friendly_id) might be more appropriate for your use case.

### Handling non-unique slugs

If a duplicate slug is to be created, a number is automatically appended to the end of the slug. For example, if there is a slug `foo`, the second one would become `foo-2`, the third `foo-3`, and so forth.

It is important to note that the maximum length of a slug does not include the addition of the sequence identifier at the end. By default the maximum length of a slug is 32 characters, but if a sequence number is added, it will be 34 characters when we append the `-2`, `-3`, etc. This was done on purpose so that the base slug always remains constant and does not get truncated.

### Defining a custom uniqueness scope

There are times when we want slugs not be unique for all objects of type `SomeObject`, but rather for a smaller scope. For example, let's say we have a system with multiple `Accounts`, each containing `Record`s. If we want the slug for the `Record` to be unique only within the scope of an `account` we can do by providing the uniqueness scope when setting up the slug.

```ruby
class Record
  include Schnecke
  slug :name, uniqueness: { scope: :account }

  belongs_to :account
end
```

When we do this, this will let us have the same slug 'foo' for multiple `record` objects as long as they belong todifferent `accounts`. Note, we can also pass an array so that we can define the scope even more narrowly. For example:

```ruby
class Tag
  include Schnecke
  slug :name, uniqueness: { scope: [:account, :record] }

  belongs_to :account
  belongs_to :record
end
```

### Callbacks

Two callbacks, `before_assign_slug` and `after_assign_slug`, are provided so that you can run arbitrary code before and after the slug assignment process. Both of these callbacks will always run regardless of whether or not a slug is to be assigned. The only time `after_assign_slug` is not run is if there is an exception raised during the assignment process.

Note, since `reassign_slug` is just a forced assignment of a slug, both callbacks will run as well.

```ruby
class SomeObject
  include Schnecke
  slug :name

  def before_assign_slug(opts={})
    puts 'Hello world! I get run before the slug assignment process'
  end

  def after_assign_slug(opts={})
    puts 'Goodbye world! I get run after the slug assignment process'
  end
end
```

### Advanced Usage

If you need to change how the slug is generated, how duplicates are handled, etc., you can overwrite the methods in your class. For example to change how slugs are generated you can overwrite the `slugify` method.

```ruby
class SomeObject
  include Schnecke
  slug :name

  # Overwrite the `slugify` method. In this case the slug will always be 'foo'
  def slugify(str)
    'foo'
  end
end
```

Note, by default the library will validate to ensure that the slug only contains lowercase alpphanumeric letters and '-' or '_'. If your new method changes the alloweable set of characters you can either disable this validation, or pass in your own validation pattern.

```ruby
class SomeObject
  include Schnecke
  slug :name, require_format: false

  def slugify(str)
    'This#Would/NormallyF@!l'
  end
end

class SomeOtherObject
  include Schnecke
  slug :name, require_format: /\A[a-z]+\z/

  def slugify(str)
    'lettersonly'
  end
end
```

The methods that can be overwritten are 

* `slugify(str)`: This is used to turn a string into a slug
* `slugify_blank`: This is used when the slug returned is blank and we need some default slug generated
* `slugify_duplicate(slug)`: This will take a slug generated by `slugify` and generate a unique version of it
* `slug_concat(parts)`: This takes an array of slugs and combines them into 1 string

For details, please see the actual code.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/prschmid/schnecke.

## Acknowledgements

This work is based on the [`slug`](https://github.com/bkoski/slug) gem.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
