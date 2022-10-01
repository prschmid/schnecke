# frozen_string_literal: true

require 'active_record'
require 'active_support/core_ext/string'

# Create temporary table-backed ActiveRecord models for use in tests.
#
# This is a copy and paste of the code in the temping gem found here
#   https://github.com/jpignata/temping
# Unfortunately, at the time of needing this library, there was a bug in that
# it didn't support Ruby 3's new keyword argument changes. There was an open
# PR on GitHub (https://github.com/jpignata/temping/pull/59), but it had
# not been merged yet. As there hadn't been any activity on that repo for
# about 4 years, it was decided to simply copy and paste the code here with
# the fix.
#
# Once the PR gets merged by the maintainer, we can remove this file and add
# the following to the Gemfile under the :test group.
#
#     # Create temporary table-backed ActiveRecord models for use in tests.
#     # https://github.com/jpignata/temping
#     gem 'temping'
class Temping
  @model_klasses = []

  class << self
    def create(model_name, options = {}, &)
      factory = ModelFactory.new(model_name.to_s.classify, options, &)
      klass = factory.klass
      @model_klasses << klass
      klass
    end

    def teardown
      return unless @model_klasses.any?

      @model_klasses.each do |klass|
        if Object.const_defined?(klass.name)
          klass.connection.drop_table(klass.table_name)
          Object.send(:remove_const, klass.name)
        end
      end
      @model_klasses.clear
      # https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html#activesupport-dependencies-private-api-has-been-deleted
      # ActiveSupport::Dependencies::Reference.clear!
    end

    def cleanup
      @model_klasses.each(&:destroy_all)
    end
  end

  # ModelFactory
  class ModelFactory
    def initialize(model_name, options = {}, &block)
      @model_name = model_name
      @options = options
      klass.class_eval(&block) if block
      klass.reset_column_information
    end

    def klass
      @klass ||= Object.const_get(@model_name)
    rescue NameError
      @klass = build
    end

    private

    def build
      Class.new(
        @options.fetch(:parent_class, default_parent_class)
      ).tap do |klass|
        Object.const_set(@model_name, klass)

        klass.primary_key = @options[:primary_key] || :id
        create_table(@options)
        add_methods
      end
    end

    def default_parent_class
      if ActiveRecord::VERSION::MAJOR > 4 && defined?(ApplicationEnhancedRecord)
        ApplicationEnhancedRecord
      else
        ActiveRecord::Base
      end
    end

    DEFAULT_OPTIONS = { temporary: true }.freeze
    def create_table(options = {})
      connection.create_table(table_name, **DEFAULT_OPTIONS.merge(options))
    end

    def add_methods
      class << klass
        def with_columns(&)
          connection.change_table(table_name, &)
        end

        def table_exists?
          true
        end
      end
    end

    def connection
      klass.connection
    end

    def table_name
      klass.table_name
    end
  end
end
