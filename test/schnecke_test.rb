# frozen_string_literal: true

require 'test_helper'

class SchneckeTest < Minitest::Test
  NAME_WITH_UNSAFE_CHARACTERS = '----!@@foo!!!!---bar %  baz------^&*'

  def teardown
    Temping.teardown
  end

  def test_that_it_has_a_version_number
    refute_nil ::Schnecke::VERSION
  end

  def test_validates_presence_of_slug
    create_dummy_schnecke_models_table

    obj = DummySchneckeModel.create!(name: 'Test Schnecke')
    obj.slug = nil
    assert_nil obj.slug
    assert_predicate obj, :invalid?

    obj.slug = SecureRandom.uuid

    assert_predicate obj, :valid?
  end

  def test_assign_slug_assigns_slugified_form_of_name
    create_dummy_schnecke_models_table

    obj = DummySchneckeModel.new(name: 'Test Schnecke')
    assert_nil obj.slug

    obj.assign_slug

    assert_equal 'test-schnecke', obj.slug
  end

  def test_raises_invalid_record_if_slug_is_not_parameterized
    create_dummy_schnecke_models_table

    assert_raises ActiveRecord::RecordInvalid do
      DummySchneckeModel.create!(
        name: 'Test name', slug: '----!@@foo!!!!---bar %  baz------^&*'
      )
    end
  end

  def test_assign_slug_sanitizes_slug_and_makes_it_query_safe_and_parameterized
    create_dummy_schnecke_models_table

    obj = DummySchneckeModel.new(name: NAME_WITH_UNSAFE_CHARACTERS)
    assert_nil obj.slug

    obj.assign_slug

    assert_equal 'foo-bar-baz', obj.slug
  end

  def test_assign_slug_assigns_slug_with_incremented_suffix
    create_dummy_schnecke_models_table

    name = 'Duplicate Name'
    obj1 = DummySchneckeModel.create!(name:)
    assert_equal 'duplicate-name', obj1.slug

    obj2 = DummySchneckeModel.new(name:)
    obj2.assign_slug
    assert_equal 'duplicate-name-2', obj2.slug
    obj2.save!

    obj2.update(slug: 'duplicate-name-100')

    obj3 = DummySchneckeModel.new(name:)
    obj3.assign_slug
    assert_equal 'duplicate-name-2', obj3.slug
  end

  def test_can_assign_slug_to_non_default_column
    create_dummy_schnecke_non_default_column_models_table

    obj = DummySchneckeNonDefaultColumnModel.new(name: 'Test Schnecke')
    assert_nil obj.slug
    assert_nil obj.another_slug_column

    obj.assign_slug

    assert_nil obj.slug
    assert_equal 'test-schnecke', obj.another_slug_column
  end

  def test_can_assign_slug_based_on_multiple_sources
    create_dummy_schnecke_multi_source_models_table

    obj = DummySchneckeMultiSourceModel.new(
      first_name: 'First',
      last_name: 'Last Schnecke'
    )
    assert_nil obj.slug

    obj.assign_slug

    assert_equal 'first-last-schnecke', obj.slug
  end

  def test_can_set_custom_uniqueness_scope
    create_dummy_schnecke_uniquness_scope_models_table

    parent1 = DummySchneckeAssociationModel.create!(name: 'Parent 1')
    child11 = DummySchneckeUniqueScopeModel.create!(
      dummy_schnecke_association_model_id: parent1.id,
      name: 'child of parent'
    )
    assert_equal 'child-of-parent', child11.slug

    child12 = DummySchneckeUniqueScopeModel.create!(
      dummy_schnecke_association_model_id: parent1.id,
      name: 'child of parent'
    )
    assert_equal 'child-of-parent-2', child12.slug

    parent2 = DummySchneckeAssociationModel.create!(name: 'Parent 2')
    child21 = DummySchneckeUniqueScopeModel.create!(
      dummy_schnecke_association_model_id: parent2.id,
      name: 'child of parent'
    )
    assert_equal 'child-of-parent', child21.slug

    child22 = DummySchneckeUniqueScopeModel.create!(
      dummy_schnecke_association_model_id: parent2.id,
      name: 'child of parent'
    )
    assert_equal 'child-of-parent-2', child22.slug
  end

  private

  def create_dummy_schnecke_models_table
    Temping.create :dummy_schnecke_models do
      include Schnecke
      slug :name

      with_columns do |t|
        t.string :name, null: false, default: 'name'
        t.string :slug

        t.timestamps index: true
      end
    end
  end

  def create_dummy_schnecke_non_default_column_models_table
    Temping.create :dummy_schnecke_non_default_column_models do
      include Schnecke
      slug :name, column: :another_slug_column

      with_columns do |t|
        t.string :name, null: false, default: 'name'
        t.string :slug
        t.string :another_slug_column

        t.timestamps index: true
      end
    end
  end

  def create_dummy_schnecke_multi_source_models_table
    Temping.create :dummy_schnecke_multi_source_models do
      include Schnecke
      slug %i[first_name last_name]

      with_columns do |t|
        t.string :first_name, null: false, default: 'first'
        t.string :last_name, null: false, default: 'last'
        t.string :slug

        t.timestamps index: true
      end
    end
  end

  def create_dummy_schnecke_uniquness_scope_models_table
    Temping.create :dummy_schnecke_association_models do
      with_columns do |t|
        t.string :name, null: false, default: 'first'
        t.string :slug

        t.timestamps index: true
      end
    end

    Temping.create :dummy_schnecke_unique_scope_models do
      include Schnecke
      slug :name, uniqueness: { scope: [:dummy_schnecke_association_model] }

      belongs_to :dummy_schnecke_association_model

      with_columns do |t|
        t.bigint :dummy_schnecke_association_model_id, null: false
        t.string :name, null: false, default: 'first'
        t.string :slug

        t.timestamps index: true
      end
    end
  end
end
