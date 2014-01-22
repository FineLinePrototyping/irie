We recommend that you use something to keep your gemset separate like RVM or rbenv (w/gemset support).

### Setup

    gem install bundler
    bundle install

### Running tests

    rake

or to run Appraisals:

    bundle exec rake appraisal:setup && bundle exec rake appraisal test

TravisCI tests in other versions of Ruby (see .travis.yml) as a GitHub hook.
