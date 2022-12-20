# frozen_string_literal: true

require 'active_support/concern'

# Adds the necessary functionality for an ActiveRecord object to have a slug
#
# See the README for usage instructions and details.
module Schnecke
  extend ActiveSupport::Concern

  SCHNECKE_DEFAULT_SLUG_COLUMN = :slug
  SCHNECKE_DEFAULT_SLUG_SEPARATOR = '-'
  SCHNECKE_DEFAULT_MAX_LENGTH = 32
  SCHNECKE_DEFAULT_REQUIRED_FORMAT = /\A[a-z0-9\-_]+\z/

  class_methods do
    # rubocop:disable Metrics/AbcSize
    def slug(source, opts = {})
      class_attribute :schnecke_config

      # Save the configuration
      self.schnecke_config = {
        slug_source: source,
        slug_column: opts.fetch(:column, SCHNECKE_DEFAULT_SLUG_COLUMN),
        slug_separator: opts.fetch(:separator, SCHNECKE_DEFAULT_SLUG_SEPARATOR),
        limit_length: opts.fetch(:limit_length, SCHNECKE_DEFAULT_MAX_LENGTH),
        required: opts.fetch(:required, true),
        generate_on_blank: opts.fetch(:generate_on_blank, true),
        require_format: opts.fetch(
          :require_format, SCHNECKE_DEFAULT_REQUIRED_FORMAT
        ),
        uniqueness: opts.fetch(:uniqueness, {})
      }

      # Setup the validations for the slug
      validates_uniqueness_of schnecke_config[:slug_column],
                              schnecke_config[:uniqueness]

      if schnecke_config[:required]
        validates schnecke_config[:slug_column],
                  presence: true
      end

      if schnecke_config[:require_format]
        validates \
          schnecke_config[:slug_column],
          format: { with: schnecke_config[:require_format],
                    message: 'contains invalid characters. Only ' \
                             "#{schnecke_config[:require_format]} are allowed" }
      end

      # Ensure the slug gets created automatically
      before_validation :assign_slug, on: :create

      include InstanceMethods
    end
    # rubocop:enable Metrics/AbcSize
  end

  # Instance methods to include
  module InstanceMethods
    # Assign the slug
    #
    # This is automatically called before model validation.
    #
    # Note, a slug will not be assigned if one already exists. If one needs to
    # force the assignment of a slug, pass `force: true`
    def assign_slug(opts = {})
      before_assign_slug(opts)
      perform_slug_assign(opts)
      after_assign_slug(opts)
    end

    # Reassign the slug
    #
    # Unlike assign_slug, this will cause a slug to be created even if one
    # already exists.
    def reassign_slug(opts = {})
      opts[:force] = true
      assign_slug(opts)
    end

    # Callback that is handled before the slug assignment process.
    #
    # When this is called, no validations, or decisions about whether or not
    # a slug should be created have been made. As such, this will always run
    # regardless of whether or not the slug assignment process proceeds or not.
    def before_assign_slug(opts = {})
      # Left blank, but can be implemented by user
    end

    # Callback that is handled after the slug is assigned
    #
    # Unless an error is raised during the slug assignment process, this method
    # will always be called regardless of whether or not the slug was assigned
    def after_assign_slug(opts = {})
      # Left blank, but can be implemented by user
    end

    protected

    # Assign the slug
    #
    # This is automatically called before model validation.
    #
    # Note, a slug will not be assigned if one already exists. If one needs to
    # force the assignment of a slug, pass `force: true`
    def perform_slug_assign(opts = {})
      validate_slug_source
      validate_slug_column

      return if !should_create_slug? && !opts[:force]

      # Generate the slug
      candidate_slug = slugify_source(schnecke_config[:slug_source])

      # If slugify returned a blank string, create one not based on the
      # source
      if candidate_slug.blank? && schnecke_config[:generate_on_blank]
        candidate_slug = slugify_blank
      end

      # Make sure it is not too long
      candidate_slug = truncate_slug(candidate_slug)

      # If there is a duplicate, create a unique one
      if slug_exists?(candidate_slug)
        candidate_slug = slugify_duplicate(candidate_slug)
      end

      self[schnecke_config[:slug_column]] = candidate_slug
    end

    # Slugify a string
    #
    # This will take a string and convert it to a slug by removing punctuation
    # and then ensuring it is downcased and has the special characters removed
    #
    # This can be overriden if a different slug generation method is needed
    def slugify(str)
      return str if str.blank?

      str = str.gsub(/[\p{Pc}\p{Ps}\p{Pe}\p{Pi}\p{Pf}\p{Po}]/, '')
      str.parameterize
    end

    # Default slug for blank strings.
    #
    # The slug to use if the string we were to use to slugify returns a blank
    # slug.
    #
    # This can be overriden if a different slug generation method is needed
    def slugify_blank
      self.class.to_s.demodulize.underscore.dasherize
    end

    # Handle the creation of a unique slug
    #
    # This assumes that the slug has already been generated with `slugify` but
    # that this value is non-unique. As such we will append '-n' to the end of
    # the slug to make it unique. The second instance gets a '-2' suffix, the
    # third will get a '-3', and so forth.
    #
    # This can be overriden if a different behavior is desired
    def slugify_duplicate(slug)
      return slug if slug.blank?

      seq = 2
      new_slug = slug_concat([slug, seq])
      while slug_exists?(new_slug)
        seq += 1
        new_slug = slug_concat([slug, seq])
      end

      new_slug
    end

    # Concatenate multiple slugified parts together
    #
    # This is used in, if the slug is to be generated from multiple
    # attributes of the model (e.g. [:first_name, :last_name]) and when we
    # append a number to the end of a slug if the initial slug wsa non-unique.
    #
    # This can be overriden if a different behavior is desired
    def slug_concat(parts)
      parts.join(schnecke_config[:slug_separator])
    end

    private

    def validate_slug_source
      source = arrayify(schnecke_config[:slug_source])
      source.each do |attr|
        unless respond_to?(attr, true)
          raise ArgumentError,
                "Source '#{attr}' does not exist."
        end
      end
    end

    def validate_slug_column
      return if respond_to?("#{schnecke_config[:slug_column]}=")

      raise ArgumentError,
            "Slug column '#{schnecke_config[:slug_column]}' does not " \
            'exist.'
    end

    def should_create_slug?
      self[schnecke_config[:slug_column]].blank?
    end

    def slugify_source(source)
      parts = arrayify(source).map do |part|
        slugify(send(part))
      end
      parts.join(schnecke_config[:slug_separator])
    end

    def truncate_slug(slug)
      return slug if slug.blank?
      return slug if schnecke_config[:limit_length].blank?

      slug[0, schnecke_config[:limit_length]]
    end

    def slug_exists?(slug)
      slug_scope.exists?(schnecke_config[:slug_column] => slug)
    end

    def slug_scope
      query = self.class.base_class
      if schnecke_config[:uniqueness].present?
        if schnecke_config[:uniqueness][:scope].present?
          scopes = arrayify(schnecke_config[:uniqueness][:scope])
          scopes.each do |scope|
            query = query.where(scope => send(scope))
          end
        elsif schnecke_config[:uniqueness][:conditions].present?
          raise 'Cannot handle uniqueness constraint parameter `:conditions`'
        end
      end
      query
    end

    def arrayify(obj)
      return obj if obj.is_a?(Array)

      [obj]
    end
  end
end
