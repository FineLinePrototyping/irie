[![Build Status](https://secure.travis-ci.org/FineLinePrototyping/irie.png?branch=master)][travis] [![Gem Version](https://badge.fury.io/rb/irie.png)][badgefury]

# Irie

Inherited Resources Including Extensions. Tested with Rails 4.0, 4.1, 4.2, Inherited Resources 1.4, 1.5, 1.6, Ruby 2.2.3, and JRuby 9.0.0.0.

Extend [Inherited Resources][inherited_resources] actions with the `extensions` method which provides symbolic references to do module includes as well as automatic inclusion of modules based on what `actions` are defined. The included extensions provide more of a DSL-like way to define your controllers. And, instead of model-heavy development via `scope` in models and `has_scope` in the controller, you can just define request parameter-based filters and their defaults in the controller. Ordering, parameter value conversion, pagination, and more are supported without additional dependencies.

```ruby
class PostsController < ApplicationController

  respond_to :json
  inherit_resources

  actions :index
  extensions :count, :limit, :offset, :paging

  can_filter_by :author, through: {author: :name}
  default_filter_by :author, eq: 'anonymous'

  can_filter_by :posted_on, using: [:lt, :eq, :gt]
  default_filter_by :posted_on, gt: 1.year.ago

  can_filter_by :company, through: {author: {company: :name}

  can_order_by :posted_on, :author, :id
  default_order_by {:posted_on => :desc}, :id

end
```

Then set up your routes and any views.

Now here are some of the URLs you can hit:

```
https://example.org/posts?author=John
https://example.org/posts?posted_on.gt=2012-08-08
https://example.org/posts?posted_on.gt=2012-08-08&count=
https://example.org/posts?company=Lipton
https://example.org/posts?page_count=
https://example.org/posts?page=1
https://example.org/posts?offset=30&limit=15
https://example.org/posts?order=author,-id
```

You can also define a query to allow only admins to see private posts:

```ruby
index_query ->(q) { @current_user.admin? ? q : q.where(:access => 'public') }
```

and change the query depending on a supplied param:

```ruby
can_filter_by_query \
    status: ->(q, status) {
      status == 'all' ? q : q.where(:status => status)
    },
    color: ->(q, color) {
      if color == 'red'
        q.where("color = 'red' or color = 'ruby'")
      else
        q.where(:color => color)
      end
    }
```

Note: `extensions` also automatically includes common sets of extensions with certain actions. So, just specify `extensions` by itself can include things you can use, e.g.

```ruby
class PostsController < ApplicationController
  inherit_resources

  actions :index
  extensions
end
```

### Installation

In your Rails app's `Gemfile`:

```ruby
gem 'irie'
```

Then:


```
bundle install
```

### Application Configuration

Each application-level configuration option can be configured one line at a time:

```ruby
::Irie.number_of_records_in_a_page = 30
```

or in bulk, like:

```ruby
::Irie.configure do
  
  # Default for :using in can_filter_by.
  self.can_filter_by_default_using = [:eq]

  # Use one or more alternate request parameter names for functions, e.g.
  # `self.function_param_names = {distinct: :very_distinct, limit: [:limit, :limita]}`
  self.function_param_names = {}
  
  # Delimiter for ARel predicate in the request parameter name.
  self.predicate_prefix = '.'

  # You'd set this to false if id is used for something else other than primary key.
  self.id_is_primary_key_param = true

  # Used when paging is enabled.
  self.number_of_records_in_a_page = 15

  # Included if the action method exists when `extensions` is called.
  self.autoincludes = {
    create: [:smart_layout],
    destroy: [:smart_layout, :query_includes],
    edit: [:smart_layout, :query_includes],
    index: [:smart_layout, :index_query, :order, :param_filters, :params_to_joins, :query_filter, :query_includes],
    new: [:smart_layout],
    show: [:smart_layout, :query_includes],
    update: [:smart_layout, :query_includes]
  }

end
```

You may want to put your configuration in an initializer like `config/initializers/irie.rb`.

### Controller Configuration

The default controller config may be fine, but you can customize it.

In the controller, you can set a variety of class attributes with `self.something = ...` in the body of your controller.

All of the app-level configuration parameters are configurable in the controller class body, e.g.:

```ruby
  self.can_filter_by_default_using = [:eq]
  self.function_param_names = {}
  self.predicate_prefix = '.'
  self.number_of_records_in_a_page = 15
  self.id_is_primary_key_param = true
```

#### About Extensions

As you may have noticed in `autoincludes`, some concerns are included as a package along with the action include.

The following assumes that you are using the default autoincludes and included the relevant action.

#### Filtering by Attribute(s)

Inherited Resources has `has_scope` via the [has_scope][has_scope] dependency, which is still available for use, and is very powerful. But, Irie also has `can_filter_by`. It is an alternative, not a replacement.

Unlike `has_scope`, `can_filter_by` doesn't require a `scope` on the model and `has_scope` on the controller. Instead you just have a single `can_filter_by` in the controller rather. Other differences are that the request parameter syntax is more brief, and it adds support for defining deeply associated attributes via either `define_params` or a `through` option.

Like the combination of `scope` and `has_scope`, `can_filter_by` filters the index action the request parameter name as a symbol will filter the results by the value of that request parameter, e.g. assuming `:eq` is in the configured `can_filter_by_default_using` in your config, as it is by default:

```ruby
can_filter_by :title
```

allows you to:

```
http://localhost:3000/posts?title=Awesome
```

or

```
http://localhost:3000/posts?title.eq=Awesome
```

Since `.eq` is optional in the param name.

And, like `has_scope`, predications are supported. Do `Arel::Predications.public_instance_methods.sort` in Rails console to see the list:

```ruby
:does_not_match, :does_not_match_all, :does_not_match_any, :eq, :eq_all, :eq_any, :gt,
:gt_all, :gt_any, :gteq, :gteq_all, :gteq_any, :in, :in_all, :in_any, :lt, :lt_all,
:lt_any, :lteq, :lteq_all, :lteq_any, :matches, :matches_all, :matches_any, :not_eq,
:not_eq_all, :not_eq_any, :not_in, :not_in_all, :not_in_any
```

You can specify these via the `using:` option:

```ruby
can_filter_by :seen_on, using: [:gteq, :eq_any]
```

For predicates that take more than one value, by default it expects that you send in multiple request parameters, that way if a value contains something that would be a delimiter of the value, you don't have to worry about additional escaping characters in the value to what you'd have to do otherwise. But, if a value is numeric, for example, you might want to be able to specify a comma-delimited list, and you can do so via:

```ruby
can_filter_by :mileage, using: [:eq_any], split: ","
```

Unlike `has_scope` which uses a much lengthier request parameter syntax, by appending the predicate prefix (`.` by default) to the request parameter name, you can use any [ARel][arel] predicate you allowed, e.g.:

```
http://localhost:3000/posts?seen_on.gteq=2012-08-08
```

And, `can_filter_by` supports (inner) joins created by `define_params` or if you'd rather, you can specify a `:through` which (inner) joins and sets the deepest symbol in the hash as the key for the parameter value, then does a where, e.g.:

```ruby
can_filter_by :name, through: {company: {employee: :full_name}}
```

If a MagicalUnicorn `has_many :friends` and a MagicalUnicorn's friend has a name attribute:

```ruby
can_filter_by :magical_unicorn_friend_name,
              through: {magical_unicorns:{friends: :name}}
```

and use this to get valleys associated with unicorns who in turn have a friend named Oscar:

```
http://localhost:3000/magical_valleys?magical_unicorn_friend_name=Oscar
```

Similar to specifying a proc/lambda in the `scope` and then using `has_scope` to use it, or defining a `scope` in the model and defining `has_scope` and passing a block into it, you can use `can_filter_by_query`, but again you only have to define something in the controller- not the model and controller. It works a little bit differently; the proc/lambda is in the context of the controller, so unlike the `has_scope` that takes a block, the `controller` doesn't have to be passed in, since that is `self`. The relation object is passed in as `q`, e.g.:

```ruby
can_filter_by_query a_request_param_name: ->(q, param_value_or_values) {
  q.joins(:some_assoc).where(some_assocs_table_name: {some_attr: param_value_or_values})
}
```

The second argument sent to the lambda (`param_value_or_values`) is the request parameter value converted by the `convert_param(param_name, param_values)` method, which may be customized through included extensions or your own extension. See elsewhere in this document for more information about the behavior of this method.

The return value of the lambda becomes the new query, so you could really change the behavior of the query depending on the request parameter provided.

##### Customizing Request Parameter Value Conversion

Implement the `convert_param(param_name, param_values)` in your controller or an included module. See [Writing Your Own Extensions](#writing-your-own-extensions) for an example.

#### Default Filters

Like the combination of `scope` and `has_scope` available via [has_scope][has_scope], which you can still use, defaults are supported that are compatible with `can_filter_by`.

Specify default filters to define attributes, ARel predicates, and values to use if no filter is provided by the client with the same param name, e.g. if you have:

```ruby
  can_filter_by :attr_name_1
  can_filter_by :production_date, :creation_date, using: [:gt, :eq, :lteq]
  default_filter_by :attr_name_1, eq: 5
  default_filter_by :production_date, :creation_date, gt: 1.year.ago,
                    lteq: 1.year.from_now
```

and both `attr_name_1` and `production_date` are supplied by the client, then it would filter by the client's `attr_name_1` and `production_date` and filter creation_date by both > 1 year ago and <= 1 year from now.

#### Extensions

##### Count

In the controller:

```ruby
extensions :count
```

enables:

```
http://localhost:3000/posts?count=
```

That will set the `@count` instance variable that you can use in your view.

Use `extensions :autorender_count` to render count automatically for non-HTML (JSON, etc.) views.

##### Page Count

In the controller:

```ruby
extensions :paging
```

enables:

```
http://localhost:3000/posts?page_count=
```

That will set the `@page_count` instance variable that you can use in your view.

Use `extensions :autorender_page_count` to render count automatically for non-HTML (JSON, etc.) views.

##### Getting a Page

In the controller:

```ruby
extensions :paging
```

To access each page of results:

```
http://localhost:3000/posts?page=1
http://localhost:3000/posts?page=2
```

To set page size at application level:

```ruby
::Irie.number_of_records_in_a_page = 15
```

To set page size at controller level:

```ruby
self.number_of_records_in_a_page = 15
```

##### Offset and Limit

In the controller:

```ruby
extensionss :offset, :limit
```

enables:

```
http://localhost:3000/posts?offset=5
http://localhost:3000/posts?limit=5
```

You can combine them to act like page:

```
http://localhost:3000/posts?limit=15
http://localhost:3000/posts?offset=15&limit=15
http://localhost:3000/posts?offset=30&limit=15
```

#### Order

You can allow request specified order:

```ruby
can_order_by :foo_date, :foo_color
```

Will let the client send the order parameter with those parameters and optional +/- prefix to designate sort direction, e.g. the following will sort by foo_date ascending then foo_color descending:

```
http://localhost:3000/posts?order=foo_date,-foo_color
```

The `default_order_by` specifies an ordered array of ascending attributes and/or hashes of attributes to sort direction: 

```ruby
default_order_by :posted_at => :desc, :id => :desc
```

or:

```ruby
default_order_by {:this_is_desc => :desc}, :this_is_asc,
                 {:no_different_than_a_symbol => :asc},
                 :this_is_asc_also, :id => :desc
```

`can_order_by` and `default_order_by` support joins/`names_params` as well as a `through` option on `can_order_by` similar to `can_filter_by`.

#### Custom Index Queries

To filter the list where the status_code attribute is 'green':

```ruby
index_query ->(q) { q.where(:status_code => 'green') }
```

You can also filter out items that have associations that don't have a certain attribute value (or anything else you can think up with [ARel][arel]/[ActiveRecord relations][ar]), e.g. to filter the list where the object's apples and pears associations are green:

```ruby
index_query ->(q) {
  q.joins(:apples, :pears)
  .where(apples: {color: 'green'})
  .where(pears: {color: 'green'})
}
```

To avoid n+1 queries, use `.includes(...)` in your query to eager load any associations that you will need in the JSON view.

#### Smart Layout

By default, Rails rendering goes through some extra hoops to attempt to find your layout unless you tell it not to, so With default autoincludes, Irie will use the `:smart_layout` extension to specify `layout: false` unless the request format is html.

#### Avoid n+1 Queries

```ruby
# load all the posts and the associated category and comments for each post
query_includes :category, :comments
```

or

```ruby
# load all of the associated posts, the associated posts’ tags and comments, and every comment’s guest association
query_includes posts: [{comments: :guest}, :tags]
```

and action-specific:

```ruby
query_includes_for :update, are: [:category, :comments]
query_includes_for :index, :show, are: [posts: [{comments: :guest}, :tags]]
```

#### Using define_params vs :through option

The `:through` option in `can_filter_by` and `can_order_by` just uses `define_params` to set the attribute name alias and options (which is parsed into a joins hash and attribute name internally). So, if you don't mind a little more typing, it might make the intent clearer, e.g.

```ruby
define_params name: {company: {employee: :full_name}},
              color: :external_color
can_filter_by :name
default_filter_by :name, eq: 'Guest'
can_order_by :color
default_filter_by :color, eq: 'blue'
```

#### Other Extensions

The following concerns, which you can include via `extensions ...` or via including the corresponding module, might also be of use in your controller:

* `:nil_params` - convert 'NULL', 'null', and 'nil' to nil when passed in as request params.

#### Writing Your Own Extensions

Extensions are just modules. There is no magic.

Some hopefully good examples of how to extend modules are in this project in `lib/irie/extensions/`.

Here's a quick example:

```ruby
module Example
  module BooleanParams
    extend ::ActiveSupport::Concern

    TRUE_VALUE = 'true'.freeze
    FALSE_VALUE = 'false'.freeze

    protected

    # Converts request param value(s) 'true' to true and 'false' to false
    def convert_param(param_name, param_value_or_values)
      logger.debug("Example::BooleanParams.convert_param(#{param_name.inspect}, #{param_value_or_values.inspect})") if ::Irie.debug?
      param_value_or_values = super if defined?(super)
      if param_value_or_values.is_a? Array
        param_value_or_values.map {|v| convert_boolean(v)}
      else
        convert_boolean(param_value_or_values)
      end
    end

    private

    def convert_boolean(value)
      case value
      when TRUE_VALUE
        true
      when FALSE_VALUE
        false
      else
        value
      end
    end
  end
end
```

If you are just doing regular `include`'s in your controllers, that's all you need, and you can include when you need to.

If you'd like to use your modules via the `extensions` method, just register the extension in an initializer, e.g. in `config/initializers/irie.rb`:

```ruby
# note: Referencing as string so we don't load the concern before it is used.
::Irie.register_extension :boolean_params, '::Example::BooleanParams'
```

Now, you could do this in your controller:

```ruby
  respond_to :json
  inherit_resources

  actions :index
  extensions :boolean_params
```

Irie includes a way to specify order of module inclusion independent of the class/module it is included in, and you can specify that at registration, e.g. in an initializer like `config/initializers/irie.rb`, you might do one of the following:

```ruby
::Irie.register_extension :boolean_params, '::Example::BooleanParams', include: :last # last is the default, so don't need to specify this option
::Irie.register_extension :boolean_params, '::Example::BooleanParams', include: :first
::Irie.register_extension :boolean_params, '::Example::BooleanParams', after: :nil_params
::Irie.register_extension :boolean_params, '::Example::BooleanParams', before: :nil_params
```

Note: an extension must be registered before you can use `after:` or `before:` to place your extension include after or before it. Use `require` and declare dependencies if possible to ensure registration of other extensions, and nothing is stopping you from registering something else. The extension class constant isn't going to be referenced by Irie until `extensions` is called with it.

The `extensions` method is just a companion to `actions` if you want to use it. You can still use [include/extend/prepend](http://ruby-doc.org/core-2.0.0/Module.html), if you'd rather.

### Troubleshooting

#### Irie::Extensions::QueryIncludes

If you get `missing FROM-clause entry for table` errors, it might mean that `query_includes`/`query_includes_for` you are using are overlapping with joins that are being done in the query. This is the nasty head of AR relational includes, unfortunately.

To fix, you may decide to either: (1) change order/definition of includes in `query_includes`/`query_includes_for`, (2) don't use `query_includes`/`query_includes_for` for the actions it affects (may cause n+1 queries), (3) implement `apply_includes` to do includes in an appropriate order (messy), or (4) use custom query (if index/custom list action) to define joins with handcoded SQL, e.g. (thanks to Tommy):

```ruby
index_query ->(q) {
  # Using standard joins performs an INNER JOIN like we want, but doesn't
  # eager load.
  # Using includes does an eager load, but does a LEFT OUTER JOIN, which
  # isn't really what we want, but in this scenario is probably ok.
  # Using standard joins & includes results in bad SQL with table aliases.
  # So, using includes & custom joins seems like a decent solution.
  q.includes(:bartender, :waitress, :owner, :customer)
    .joins('INNER JOIN employees bartenders ON bartenders.employee_id = ' +
    'shifts.bartender_id')
    .joins('INNER JOIN waitresses shift_workers ON shift_workers.id = ' +
    'shifts.waitress_id')
    .where(bartenders: {certified: 'yes'})
    .where(shift_workers: {attitude: 'great'})
}

# set includes for all actions except index
query_includes :owner, :customer, :bartender, :waitress

# includes specified in index query
query_includes_for :index, are: []
```

#### Debugging Includes

##### Logging

If you enabled Irie's debug option via:

```ruby
::Irie.debug = true
```

Then all the included modules (actions, extensions) will use `logger.debug ...` to log some information about what is executed.

To log debug to console only in your tests, you could put this in your test helper:

```ruby
::Irie.debug = true
::ActionController::Base.logger = Logger.new(STDOUT)
::ActionController::Base.logger.level = Logger::DEBUG
```

However, that might not catch all the initialization debug logging that could occur. Instead, you might put the following into the block in `config/environments/test.rb`:

```ruby
::Irie.debug = true
config.log_level = :debug
```

If you are really having trouble tracking down a problem and can live with the significant impact of increasing the number and result size of queries and are ok with a lot more data being logged, you can turn on more verbose debug logging via:

```ruby
::Irie.debug = ::Irie.verbose = true
```

### restful_json

The project was originally named [restful_json][restful_json]. Old commit tags corresponding to restful_json versions may be found in [legacy][legacy].

### Release Notes

See [changelog][changelog] and git log.

### Contributing

Please fork, make changes in a separate branch, and do a pull request. Thanks!

### Authors

This was written by [FineLine Prototyping, Inc.](http://www.finelineprototyping.com) by the following contributors:
* [Gary Weaver](https://github.com/garysweaver)
* [Tommy Odom](https://github.com/tpodom)

### License

Copyright (c) 2013 FineLine Prototyping, Inc., released under the [MIT license][lic].

[travis]: http://travis-ci.org/FineLinePrototyping/irie
[badgefury]: http://badge.fury.io/rb/irie
[arel]: https://github.com/rails/arel
[ar]: http://api.rubyonrails.org/classes/ActiveRecord/Relation.html
[has_scope]: https://github.com/plataformatec/has_scope
[public_exceptions]: https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/public_exceptions.rb
[show_exceptions]: https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/show_exceptions.rb
[changelog]: https://github.com/FineLinePrototyping/irie/blob/master/CHANGELOG.md
[inherited_resources]: https://github.com/josevalim/inherited_resources
[restful_json]: http://rubygems.org/gems/restful_json
[legacy]: http://github.com/FineLinePrototyping/irie/blob/master/LEGACY.md
[lic]: http://github.com/FineLinePrototyping/irie/blob/master/LICENSE
